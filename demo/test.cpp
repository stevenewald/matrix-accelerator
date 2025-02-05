#include <array>
#include <cstdint>
#include <cstring>
#include <fcntl.h>
#include <iostream>
#include <unistd.h>

#define DEVICE_PATH "/dev/fpga"

int main() {
  int fd = open(DEVICE_PATH, O_RDWR);
  if (fd < 0) {
    std::cerr << "Failed to open " << DEVICE_PATH << std::endl;
    return 1;
  }

  const std::array<uint32_t, 9> inputs = {50, 20, 30, 40, 50, 60, 70, 80, 1};
  off_t offset = 0;
  ssize_t bytes_written =
      pwrite(fd, inputs.data(), inputs.size() * sizeof(uint32_t), offset);
  if (bytes_written < 0) {
    std::cerr << "pwrite failed" << std::endl;
    close(fd);
    return 1;
  }

  std::array<uint32_t, 4> res;
  offset = 36;
  ssize_t bytes_read =
      pread(fd, res.data(), res.size() * sizeof(uint32_t) - 1, offset);
  if (bytes_read < 0) {
    std::cerr << "pread failed" << std::endl;
    close(fd);
    return 1;
  }

  for (auto r : res) {
    std::cout << "val: " << r << "\n";
  }

  close(fd);
  return 0;
}
