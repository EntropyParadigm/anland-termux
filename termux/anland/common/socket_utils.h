#ifndef DISPLAY_SOCKET_UTILS_H
#define DISPLAY_SOCKET_UTILS_H

#include <stddef.h>
#include <sys/socket.h>
#include <sys/un.h>

int send_fds(int sock, const void *data, size_t data_len,
             const int *fds, int fd_count);

int recv_fds(int sock, void *data, size_t data_len,
             int *fds, int fd_count, int *fds_received);

/* Fill *addr for PATH and store the length to pass to bind()/connect() in
 * *addr_len. A path starting with '@' selects the Linux abstract namespace:
 * sun_path[0] stays '\0', the name follows without a trailing NUL. Returns -1
 * if the path does not fit. */
int unix_sockaddr(struct sockaddr_un *addr, socklen_t *addr_len,
                  const char *path);

int connect_unix(const char *path);

int send_all(int fd, const void *buf, size_t len);

int recv_all(int fd, void *buf, size_t len);

#endif
