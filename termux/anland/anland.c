#include <errno.h>
#include <signal.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/epoll.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/un.h>
#include <unistd.h>

#include "common/protocol.h"
#include "common/socket_utils.h"

#define MAX_EVENTS 16
#define MAX_FDS    4
#define DEFAULT_TERMUX_TMP "/data/data/com.termux/files/usr/tmp"
#define DEFAULT_SOCKET_RELATIVE "anland/display_daemon.sock"

struct client {
    int  ctrl_fd;
    bool is_consumer;
};

static struct client *consumer;
static struct client *producer;
static int epoll_fd;
static volatile bool running = true;

static struct screen_info stored_screen;
static bool has_screen_info;

static int deposited_fds[MAX_FDS];
static int deposited_fd_count;

static bool producer_waiting_screen;
static bool producer_waiting_fds;

static void handle_signal(int sig)
{
    (void)sig;
    running = false;
}

static void client_free(struct client *c)
{
    if (!c) return;
    if (c->ctrl_fd >= 0) {
        epoll_ctl(epoll_fd, EPOLL_CTL_DEL, c->ctrl_fd, NULL);
        close(c->ctrl_fd);
    }
    free(c);
}

static void clear_deposited_fds(void)
{
    for (int i = 0; i < deposited_fd_count; i++)
        close(deposited_fds[i]);
    deposited_fd_count = 0;
}

static int send_ctrl(int fd, uint32_t type)
{
    struct ctrl_msg msg = { .type = type, .size = 0 };
    return send_all(fd, &msg, sizeof(msg));
}

static int send_screen_info_msg(int fd)
{
    struct ctrl_msg hdr = { .type = CTRL_MSG_SCREEN_INFO, .size = sizeof(struct screen_info) };
    uint8_t buf[sizeof(struct ctrl_msg) + sizeof(struct screen_info)];
    memcpy(buf, &hdr, sizeof(hdr));
    memcpy(buf + sizeof(hdr), &stored_screen, sizeof(stored_screen));
    return send_all(fd, buf, sizeof(buf));
}

static void try_deliver_fds(void)
{
    if (!producer || deposited_fd_count < 4) {
        producer_waiting_fds = true;
        return;
    }

    struct ctrl_msg msg = { .type = CTRL_MSG_FDS_READY, .size = 0 };
    if (send_fds(producer->ctrl_fd, &msg, sizeof(msg),
                 deposited_fds, deposited_fd_count) < 0) {
        fprintf(stderr, "daemon: failed to send fds to producer\n");
        producer_waiting_fds = true;
        return;
    }

    if (consumer)
        send_ctrl(consumer->ctrl_fd, CTRL_MSG_FDS_READY);

    for (int i = 0; i < deposited_fd_count; i++)
        close(deposited_fds[i]);
    deposited_fd_count = 0;
    producer_waiting_fds = false;

    fprintf(stderr, "daemon: fds delivered to producer\n");
}

static void handle_disconnect(struct client *c)
{
    if (c == consumer) {
        fprintf(stderr, "daemon: consumer disconnected\n");
        client_free(consumer);
        consumer = NULL;
    } else if (c == producer) {
        fprintf(stderr, "daemon: producer disconnected\n");
        client_free(producer);
        producer = NULL;
        producer_waiting_screen = false;
        producer_waiting_fds = false;
    }
}

static void handle_client_data(struct client *c)
{
    struct ctrl_msg hdr;
    int fds[MAX_FDS];
    int fd_count = 0;

    int n = recv_fds(c->ctrl_fd, &hdr, sizeof(hdr), fds, MAX_FDS, &fd_count);
    if (n <= 0) {
        handle_disconnect(c);
        return;
    }

    uint8_t payload[sizeof(struct screen_info)];
    if (hdr.size > 0) {
        if (hdr.size > sizeof(payload) || recv_all(c->ctrl_fd, payload, hdr.size) < 0) {
            handle_disconnect(c);
            return;
        }
    }

    switch (hdr.type) {
    case CTRL_MSG_CONSUMER_HELLO:
        if (c == consumer && fd_count >= 3) {
            clear_deposited_fds();
            memcpy(deposited_fds, fds, sizeof(int) * fd_count);
            deposited_fd_count = fd_count;
            fprintf(stderr, "daemon: consumer re-deposited %d fds\n", fd_count);
            if (producer_waiting_fds)
                try_deliver_fds();
        }
        break;

    case CTRL_MSG_SCREEN_INFO:
        if (c == consumer && hdr.size == sizeof(struct screen_info)) {
            struct screen_info si;
            memcpy(&si, payload, sizeof(si));
            if (has_screen_info) {
                if (memcmp(&si, &stored_screen, sizeof(si)) != 0) {
                    fprintf(stderr, "daemon: rejecting consumer (screen info mismatch)\n");
                    send_ctrl(c->ctrl_fd, CTRL_MSG_REJECT);
                    handle_disconnect(c);
                    return;
                }
            } else {
                stored_screen = si;
                has_screen_info = true;
                fprintf(stderr, "daemon: screen info %ux%u fmt=%u\n",
                        si.width, si.height, si.format);
            }
            if (producer_waiting_screen && producer) {
                send_screen_info_msg(producer->ctrl_fd);
                producer_waiting_screen = false;
            }
        }
        break;

    case CTRL_MSG_PICKUP_FDS:
        if (c == producer)
            try_deliver_fds();
        break;

    default:
        break;
    }
}

static void handle_new_connection(int listen_fd)
{
    int client_fd = accept(listen_fd, NULL, NULL);
    if (client_fd < 0)
        return;

    struct ctrl_msg hdr;
    int fds[MAX_FDS];
    int fd_count = 0;

    int n = recv_fds(client_fd, &hdr, sizeof(hdr), fds, MAX_FDS, &fd_count);
    if (n < (int)sizeof(struct ctrl_msg)) {
        close(client_fd);
        return;
    }

    struct client *c = calloc(1, sizeof(*c));
    c->ctrl_fd = client_fd;

    if (hdr.type == CTRL_MSG_CONSUMER_HELLO) {
        if (consumer)
            client_free(consumer);
        c->is_consumer = true;
        consumer = c;

        clear_deposited_fds();
        memcpy(deposited_fds, fds, sizeof(int) * fd_count);
        deposited_fd_count = fd_count;
        fprintf(stderr, "daemon: consumer connected, %d fds\n", fd_count);

        if (producer_waiting_fds)
            try_deliver_fds();

    } else if (hdr.type == CTRL_MSG_PRODUCER_HELLO) {
        if (producer)
            client_free(producer);
        c->is_consumer = false;
        producer = c;
        producer_waiting_screen = false;
        producer_waiting_fds = false;
        fprintf(stderr, "daemon: producer connected\n");

        if (has_screen_info)
            send_screen_info_msg(client_fd);
        else
            producer_waiting_screen = true;

    } else {
        close(client_fd);
        free(c);
        return;
    }

    struct epoll_event ev = { .events = EPOLLIN | EPOLLHUP | EPOLLERR, .data.ptr = c };
    epoll_ctl(epoll_fd, EPOLL_CTL_ADD, client_fd, &ev);
}

static int mkdir_p(const char *path)
{
    char tmp[4096];
    size_t len = strlen(path);
    if (len == 0 || len >= sizeof(tmp)) {
        errno = ENAMETOOLONG;
        return -1;
    }

    memcpy(tmp, path, len + 1);
    if (tmp[len - 1] == '/')
        tmp[len - 1] = '\0';

    for (char *p = tmp + 1; *p; p++) {
        if (*p != '/')
            continue;
        *p = '\0';
        if (mkdir(tmp, 0700) < 0 && errno != EEXIST)
            return -1;
        *p = '/';
    }

    if (mkdir(tmp, 0700) < 0 && errno != EEXIST)
        return -1;
    return 0;
}

static int ensure_parent_dir(const char *sock_path)
{
    char dir[4096];
    size_t len = strlen(sock_path);
    if (len == 0 || len >= sizeof(dir)) {
        errno = ENAMETOOLONG;
        return -1;
    }

    memcpy(dir, sock_path, len + 1);
    char *slash = strrchr(dir, '/');
    if (!slash)
        return 0;
    if (slash == dir)
        return 0;
    *slash = '\0';
    return mkdir_p(dir);
}

static const char *default_socket_path(char *buf, size_t size)
{
    const char *tmpdir = getenv("TMPDIR");
    if (!tmpdir || !tmpdir[0])
        tmpdir = DEFAULT_TERMUX_TMP;

    if (snprintf(buf, size, "%s/%s", tmpdir, DEFAULT_SOCKET_RELATIVE) >= (int)size) {
        errno = ENAMETOOLONG;
        return NULL;
    }
    return buf;
}

static const char *resolve_socket_path(int argc, char **argv, char *buf, size_t size)
{
    if (argc > 1) {
        if (strcmp(argv[1], "--socket") == 0) {
            if (argc < 3) {
                fprintf(stderr, "usage: anland [--socket PATH] [PATH]\n");
                return NULL;
            }
            return argv[2];
        }
        return argv[1];
    }

    return default_socket_path(buf, size);
}

int main(int argc, char **argv)
{
    char default_path[4096];
    const char *sock_path = resolve_socket_path(argc, argv, default_path, sizeof(default_path));
    if (!sock_path)
        return 1;

    if (strlen(sock_path) >= sizeof(((struct sockaddr_un *)0)->sun_path)) {
        fprintf(stderr, "anland: socket path too long for AF_UNIX: %s\n", sock_path);
        return 1;
    }

    if (ensure_parent_dir(sock_path) < 0) {
        perror("mkdir socket directory");
        return 1;
    }

    signal(SIGINT, handle_signal);
    signal(SIGTERM, handle_signal);
    signal(SIGPIPE, SIG_IGN);

    unlink(sock_path);
    int listen_fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (listen_fd < 0) {
        perror("socket");
        return 1;
    }

    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    memcpy(addr.sun_path, sock_path, strlen(sock_path) + 1);

    if (bind(listen_fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        perror("bind");
        return 1;
    }
    if (listen(listen_fd, 4) < 0) {
        perror("listen");
        return 1;
    }

    epoll_fd = epoll_create1(0);
    struct epoll_event ev = { .events = EPOLLIN, .data.ptr = NULL };
    epoll_ctl(epoll_fd, EPOLL_CTL_ADD, listen_fd, &ev);

    fprintf(stderr, "daemon: listening on %s\n", sock_path);

    struct epoll_event events[MAX_EVENTS];
    while (running) {
        int nfds = epoll_wait(epoll_fd, events, MAX_EVENTS, 1000);
        for (int i = 0; i < nfds; i++) {
            if (events[i].data.ptr == NULL) {
                handle_new_connection(listen_fd);
            } else {
                struct client *c = events[i].data.ptr;
                if (events[i].events & (EPOLLHUP | EPOLLERR))
                    handle_disconnect(c);
                else
                    handle_client_data(c);
            }
        }
    }

    clear_deposited_fds();
    client_free(consumer);
    client_free(producer);
    close(listen_fd);
    close(epoll_fd);
    unlink(sock_path);
    fprintf(stderr, "daemon: shutdown\n");
    return 0;
}
