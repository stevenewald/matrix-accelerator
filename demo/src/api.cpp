#include "api.hpp"
#include <iostream>
#include <stdexcept>
#include <stdio.h>

void set_write_mode(int fd, WriteMode write_mode) {
  int dma_on = write_mode == WriteMode::DMA ? 1 : 0;
  if (ioctl(fd, PCIE_SET_DMA, &dma_on) < 0) {
    perror("ioctl failed");
  }
}

namespace {
bool dimensions_invalid(const matmul_dims &dims) {
  if (dims.m % TILE_DIM != 0)
    return true;
  if (dims.k % TILE_DIM != 0)
    return true;
  if (dims.n % TILE_DIM != 0)
    return true;
  return 256 + sizeof(uint16_t) * (dims.m * dims.k + dims.k * dims.n) +
             sizeof(uint32_t) * dims.m * dims.n >
         std::pow(2, 16);
}
} // namespace

bool start_mul(int fd, const matmul_dims &dims) {
  if (dimensions_invalid(dims)) {
    throw std::invalid_argument("Invalid matrix dimensions");
  }

  set_write_mode(fd, WriteMode::MMIO);
  uint32_t arg = (dims.n << 20) | (dims.k << 10) | (dims.m);
  if (pwrite(fd, &arg, sizeof(uint32_t), 0) != sizeof(uint32_t)) {
    std::cerr << "matrix start mul failed" << std::endl;
    return false;
  }
  return true;
}

bool write_matrices(int fd, const matrix_input &a, const matrix_input &b) {
  set_write_mode(fd, WriteMode::DMA);

  std::vector<int16_t> args(a.size() + b.size());

  std::copy(a.begin(), a.end(), args.begin());
  std::copy(b.begin(), b.end(), args.begin() + a.size());

  off_t offset = 32;
  ssize_t bytes_written =
      pwrite(fd, args.data(), args.size() * sizeof(int16_t), offset);
  if (bytes_written != args.size() * sizeof(int16_t)) {
    std::cerr << "matrix pwrite failed" << std::endl;
    close(fd);
    return false;
  }
  return true;
}

matrix_res get_large_result(int fd, const matmul_dims &dims) {
  set_write_mode(fd, WriteMode::DMA);
  matrix_res res(dims.m * dims.n);
  off_t offset = 32 + 2 * (dims.m * dims.k + dims.k * dims.n);
  ssize_t bytes_read =
      pread(fd, res.data(), res.size() * sizeof(int32_t), offset);
  if (bytes_read != res.size() * sizeof(int32_t)) {
    std::cerr << "pread failed, read " << bytes_read << " bytes instead of "
              << dims.n * dims.n * 4 << std::endl;
    close(fd);
    throw std::runtime_error("Failed to read result matrix");
  }
  return res;
}

int get_cycles_elapsed(int fd) {
  set_write_mode(fd, WriteMode::MMIO);
  int32_t res;
  off_t offset = 4;
  ssize_t bytes_read = pread(fd, &res, sizeof(int32_t), offset);
  if (bytes_read != sizeof(int32_t)) {
    std::cerr << "pread failed, read " << bytes_read << " bytes instead of "
              << sizeof(int32_t) << "bytes\n";
    close(fd);
    throw std::runtime_error("Failed to read result matrix");
  }
  return res;
}

void wait_for_execution_complete(int fd) {
  struct pollfd pfd = {.fd = fd, .events = POLLIN};

  while (true) {
    poll(&pfd, 1, -1);
    if (pfd.revents & POLLIN)
      break;
  }
}
