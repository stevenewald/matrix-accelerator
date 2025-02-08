#include <array>
#include <cstdint>
#include <cstring>
#include <fcntl.h>
#include <iostream>
#include <unistd.h>

#define DEVICE_PATH "/dev/fpga"

using matrix = std::array<uint32_t, 9>;
bool write_matrices(int fd, const matrix &a, const matrix &b) {
  std::array<uint32_t, 19> args;
  std::copy(a.begin(), a.end(), args.begin());
  std::copy(b.begin(), b.end(), args.begin() + 9);
  args[args.size() - 1] = 1; // start

  off_t offset = 0;
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

  matrix mat_a = {10, 20, 30, 40, 50, 60, 70, 80, 90};
  matrix mat_b = {100, 110, 120, 130, 140, 150, 160, 170, 180};

  if (!write_matrices(fd, mat_a, mat_b)) {
    return 1;
  }

  auto res = get_result(fd);

  for (auto r : res) {
    std::cout << "val: " << r << "\n";
  }

  close(fd);
  return 0;
}
