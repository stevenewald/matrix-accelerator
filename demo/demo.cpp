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
    std::cerr << "small_matrix start mul failed" << std::endl;
    return false;
  }
  return true;
}

using small_matrix = std::array<uint32_t, 9>;
using large_matrix = std::array<uint32_t, 81>;
bool write_matrices(int fd, const small_matrix &a, const small_matrix &b) {
  set_write_mode(fd, true);
  std::array<uint32_t, 18> args;
  std::copy(a.begin(), a.end(), args.begin());
  std::copy(b.begin(), b.end(), args.begin() + 9);

  off_t offset = 4;
  ssize_t bytes_written =
      pwrite(fd, args.data(), args.size() * sizeof(uint32_t), offset);
  if (bytes_written != args.size() * sizeof(uint32_t)) {
    std::cerr << "small_matrix pwrite failed" << std::endl;
    close(fd);
    return false;
  }
  return true;
}

bool write_matrices(int fd, const large_matrix &a, const large_matrix &b) {
  set_write_mode(fd, true);
  std::array<uint32_t, 162> args;
  std::copy(a.begin(), a.end(), args.begin());
  std::copy(b.begin(), b.end(), args.begin() + 81);

  off_t offset = 4;
  ssize_t bytes_written =
      pwrite(fd, args.data(), args.size() * sizeof(uint32_t), offset);
  if (bytes_written != args.size() * sizeof(uint32_t)) {
    std::cerr << "large_matrix pwrite failed" << std::endl;
    close(fd);
    return false;
  }
  return true;
}

small_matrix get_small_result(int fd) {
  set_write_mode(fd, true);
  std::array<uint32_t, 9> res;
  off_t offset = 76;
  ssize_t bytes_read =
      pread(fd, res.data(), res.size() * sizeof(uint32_t) - 1, offset);
  if (bytes_read < 0) {
    std::cerr << "pread failed" << std::endl;
    close(fd);
    throw std::runtime_error("Failed to read result small_matrix");
  }
  return res;
}

large_matrix get_large_result(int fd) {
  set_write_mode(fd, true);
  std::array<uint32_t, 81> res;
  off_t offset = 652;
  ssize_t bytes_read =
      pread(fd, res.data(), res.size() * sizeof(uint32_t) - 1, offset);
  if (bytes_read < 0) {
    std::cerr << "pread failed" << std::endl;
    close(fd);
    throw std::runtime_error("Failed to read result large_matrix");
  }
  return res;
}

bool verify_result(const small_matrix &a, const small_matrix &b,
                   const small_matrix &res) {
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

bool verify_result(const large_matrix &a, const large_matrix &b,
                   const large_matrix &res) {
  for (int row = 0; row < 9; row++) {
    for (int col = 0; col < 9; col++) {
      int expected = 0;
      for (int k = 0; k < 9; k++) {
        expected += a[row * 9 + k] * b[k * 9 + col];
      }
      if (res[row * 9 + col] != expected) {
        return false;
      }
    }
  }
  return true;
}

large_matrix transform_into_input(const large_matrix &input) {
  large_matrix res;

  for (int i = 0; i < 81; ++i) {
    res[i] = input[(i / 27) * 18 + (i / 9) * 3 + ((i % 9) / 3) * 9 + i % 3];
  }

  return res;
}

large_matrix transform_into_output(const large_matrix &input) {
  large_matrix res;

  for (int i = 0; i < 81; ++i) {
    res[(i / 27) * 18 + (i / 9) * 3 + ((i % 9) / 3) * 9 + i % 3] = input[i];
  }

  return res;
}

void wait_for_poll(int fd) {
  struct pollfd pfd = {.fd = fd, .events = POLLIN};

  while (true) {
    poll(&pfd, 1, -1);
    if (pfd.revents & POLLIN)
      break;
  }
}

void print_matrix(const large_matrix &matrix) {
  for (int i = 0; i < matrix.size(); ++i) {
    if (i % 9 == 0)
      std::cout << "\n";
    std::cout << matrix[i] << " ";
  }
  std::cout << "\n\n";
}

int main() {
  int fd = open(DEVICE_PATH, O_RDWR);
  if (fd < 0) {
    std::cerr << "Failed to open " << DEVICE_PATH << std::endl;
    return 1;
  }

  std::random_device rd;
  std::mt19937 gen(rd());
  std::uniform_int_distribution<int> dist(0, 500);

  large_matrix mat_a;
  large_matrix mat_b;

  for (int i = 0; i < 81; i++) {
    mat_a[i] = dist(gen);
    mat_b[i] = dist(gen);
  }

  large_matrix mat_a_t = transform_into_input(mat_a);
  large_matrix mat_b_t = transform_into_input(mat_b);

  if (!write_matrices(fd, mat_a_t, mat_b_t)) {
    return 1;
  }

  if (!start_mul(fd)) {
    return 1;
  }

  wait_for_poll(fd);

  auto res = get_large_result(fd);

  auto res_t = transform_into_output(res);

  print_matrix(res_t);

  if (verify_result(mat_a, mat_b, res_t)) {
    std::cout << "PASS\n";
  } else {
    std::cout << "FAIL\n";
  }

  close(fd);
  return 0;
}
