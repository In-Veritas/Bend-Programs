// lan_ip() -> IO<Result<String>>
// Report the IPv4 source address chosen by the default route. Connecting a
// UDP socket only asks the kernel to select a route; it sends no packet.
#include <arpa/inet.h>
#include <errno.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>

static Term io_lan_ip(State st) {
  int fd = socket(AF_INET, SOCK_DGRAM, 0);
  if (fd < 0) {
    return io_fail(st, (u32)errno, strerror(errno));
  }
  struct sockaddr_in probe;
  memset(&probe, 0, sizeof(probe));
  probe.sin_family = AF_INET;
  probe.sin_addr.s_addr = htonl(0x08080808u);
  probe.sin_port = htons(53);
  if (connect(fd, (struct sockaddr*)&probe, sizeof(probe)) != 0) {
    int error = errno;
    close(fd);
    return io_fail(st, (u32)error, strerror(error));
  }
  struct sockaddr_in address;
  socklen_t length = sizeof(address);
  memset(&address, 0, sizeof(address));
  if (getsockname(fd, (struct sockaddr*)&address, &length) != 0) {
    int error = errno;
    close(fd);
    return io_fail(st, (u32)error, strerror(error));
  }
  char text[INET_ADDRSTRLEN];
  if (inet_ntop(AF_INET, &address.sin_addr, text, sizeof(text)) == NULL) {
    int error = errno;
    close(fd);
    return io_fail(st, (u32)error, strerror(error));
  }
  close(fd);
  return io_done(st, io_str_make(st, text, strlen(text)));
}
