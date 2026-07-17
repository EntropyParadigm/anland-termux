#ifndef DISPLAY_SOCKET_UTILS_H
#define DISPLAY_SOCKET_UTILS_H

#include <stddef.h>
#include <sys/socket.h>
#include <sys/un.h>

int send_fds(int sock, const void *data, size_t data_len,
             const int *fds, int fd_count);

int recv_fds(int sock, void *data, size_t data_len,
             int *fds, int fd_count, int *fds_received);

/* Fill *addr from a socket "path" for connect()/bind(). A leading '@' selects
 * the Linux abstract namespace: sun_path[0] = '\0' followed by the name (no
 * trailing NUL). Returns the address length to pass to connect()/bind(), or 0
 * if the name is empty or too long. */
socklen_t unix_sockaddr(struct sockaddr_un *addr, const char *path);

int connect_unix(const char *path);

int send_all(int fd, const void *buf, size_t len);

int recv_all(int fd, void *buf, size_t len);

#endif
