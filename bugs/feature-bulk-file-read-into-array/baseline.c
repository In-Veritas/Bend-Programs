/* Same work in C: 1 MiB reads, sum of every byte. */
#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
int main(int c, char **v) {
  static unsigned char b[1 << 20]; unsigned s = 0; ssize_t n;
  int fd = open(v[1], O_RDONLY);
  while ((n = read(fd, b, sizeof b)) > 0) for (ssize_t i = 0; i < n; i++) s += b[i];
  printf("%u\n", s); return 0;
}
