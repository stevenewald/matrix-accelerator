#include <array>
#include <cstdint>
#include <cstring>
#include <fcntl.h>
#include <iostream>
#include <random>
#include <sys/ioctl.h>
#include <sys/poll.h>
#include <unistd.h>

#define DEVICE_PATH "/dev/fpga"
#define PCIE_SET_DMA (_IOW('k', 1, int))

void set_write_mode(int fd, int dma_on) {
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

bool verify_result(const matrix &a, const matrix &b, const matrix &res) {
  for (int row = 0; row < 3; row++) {
    for (int col = 0; col < 3; col++) {
      if (res[row * 3 + col] != a[row * 3 + 0] * b[0 * 3 + col] +
                                    a[row * 3 + 1] * b[1 * 3 + col] +
                                    a[row * 3 + 2] * b[2 * 3 + col]) {
        return false;
      }
    }
  }
  return true;
}

void wait_for_poll(int fd) {
  struct pollfd pfd = {.fd = fd, .events = POLLIN};

  while (true) {
    poll(&pfd, 1, -1);
    if (pfd.revents & POLLIN)
      break;
  }
}

int main() {
  int fd = open(DEVICE_PATH, O_RDWR);
  if (fd < 0) {
    std::cerr << "Failed to open " << DEVICE_PATH << std::endl;
    return 1;
  }

  std::random_device rd;
  std::mt19937 gen(rd());
  std::uniform_int_distribution<int> dist(0, 100);

  matrix mat_a;
  matrix mat_b;

  for (int i = 0; i < 9; i++) {
    mat_a[i] = dist(gen);
    mat_b[i] = dist(gen);
  }

  if (!write_matrices(fd, mat_a, mat_b)) {
    return 1;
  }

  if (!start_mul(fd)) {
    return 1;
  }

  wait_for_poll(fd);

  auto res = get_result(fd);

  if (verify_result(mat_a, mat_b, res)) {
    std::cout << "PASS\n";
  } else {
    std::cout << "FAIL\n";
  }

  for (auto r : res) {
    std::cout << "val: " << r << "\n";
  }

  close(fd);
  return 0;
}
