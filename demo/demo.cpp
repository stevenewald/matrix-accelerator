#include <array>
#include <cstdint>
#include <cstring>
#include <fcntl.h>
#include <iostream>
#include <sys/ioctl.h>
#include <unistd.h>

#define DEVICE_PATH "/dev/fpga"
#define PCIE_SET_DMA (_IOW('k', 1, int))

void set_write_mode(int fd, bool dma_on) {
  if (ioctl(fd, PCIE_SET_DMA, &dma_on) < 0) {
    perror("ioctl failed");
  }
}

bool start_mul(int fd) {
  set_write_mode(fd, false);
  int arg = 1;
  if (pwrite(fd, &arg, 1 * sizeof(int), 0) != 1 * sizeof(int)) {
    std::cerr << "matrix start mul failed" << std::endl;
    return false;
  }
  return true;
}

using matrix = std::array<uint32_t, 9>;
bool write_matrices(int fd, const matrix &a, const matrix &b) {
  set_write_mode(fd, true);
  std::array<uint32_t, 18> args;
  std::copy(a.begin(), a.end(), args.begin());
  std::copy(b.begin(), b.end(), args.begin() + 9);

  off_t offset = 4;
  ssize_t bytes_written =
      pwrite(fd, args.data(), args.size() * sizeof(uint32_t), offset);
  if (bytes_written != args.size() * sizeof(uint32_t)) {
    std::cerr << "matrix pwrite failed" << std::endl;
    close(fd);
    return false;
  }
  return true;
}

std::array<uint32_t, 9> get_result(int fd) {
  set_write_mode(fd, true);
  std::array<uint32_t, 9> res;
  off_t offset = 76;
  ssize_t bytes_read =
      pread(fd, res.data(), res.size() * sizeof(uint32_t) - 1, offset);
  if (bytes_read < 0) {
    std::cerr << "pread failed" << std::endl;
    close(fd);
    throw std::runtime_error("Failed to read result matrix");
  }
  return res;
}

int main() {
  int fd = open(DEVICE_PATH, O_RDWR);
  if (fd < 0) {
    std::cerr << "Failed to open " << DEVICE_PATH << std::endl;
    return 1;
  }

  matrix mat_a = {20, 20, 30, 40, 50, 60, 70, 80, 90};
  matrix mat_b = {100, 110, 120, 130, 140, 150, 160, 170, 180};

  if (!write_matrices(fd, mat_a, mat_b)) {
    return 1;
  }

  if (!start_mul(fd)) {
    return 1;
  }

  usleep(1000);

  auto res = get_result(fd);

  for (auto r : res) {
    std::cout << "val: " << r << "\n";
  }

  close(fd);
  return 0;
}
