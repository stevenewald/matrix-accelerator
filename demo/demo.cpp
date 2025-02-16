#include <array>
#include <cstdint>
#include <cstring>
#include <fcntl.h>
#include <iostream>
#include <random>
#include <sys/ioctl.h>
#include <sys/poll.h>
#include <unistd.h>

#define TILE_DIM 2
#define INPUT_DIM 20

#define DEVICE_PATH "/dev/fpga"
#define PCIE_SET_DMA (_IOW('k', 1, int))

void set_write_mode(int fd, int dma_on) {
  if (ioctl(fd, PCIE_SET_DMA, &dma_on) < 0) {
    perror("ioctl failed");
  }
}

bool start_mul(int fd) {
  set_write_mode(fd, false);
  int arg = INPUT_DIM;
  if (pwrite(fd, &arg, 1 * sizeof(int), 0) != 1 * sizeof(int)) {
    std::cerr << "matrix start mul failed" << std::endl;
    return false;
  }
  return true;
}

using large_matrix = std::array<uint32_t, INPUT_DIM * INPUT_DIM>;

bool write_matrices(int fd, const large_matrix &a, const large_matrix &b) {
  set_write_mode(fd, true);
  std::array<uint32_t, INPUT_DIM * INPUT_DIM * 2> args;
  std::copy(a.begin(), a.end(), args.begin());
  std::copy(b.begin(), b.end(), args.begin() + INPUT_DIM * INPUT_DIM);

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

large_matrix get_large_result(int fd) {
  set_write_mode(fd, true);
  std::array<uint32_t, INPUT_DIM * INPUT_DIM> res;
  off_t offset = 4 * (1 + INPUT_DIM * INPUT_DIM * 2);
  ssize_t bytes_read =
      pread(fd, res.data(), res.size() * sizeof(uint32_t), offset);
  if (bytes_read != res.size() * sizeof(uint32_t)) {
    std::cerr << "pread failed, read " << bytes_read << " bytes instead of "
              << INPUT_DIM * INPUT_DIM * 4 - 1 << std::endl;
    close(fd);
    throw std::runtime_error("Failed to read result large_matrix");
  }
  return res;
}

bool verify_result(const large_matrix &a, const large_matrix &b,
                   const large_matrix &res) {
  for (int row = 0; row < INPUT_DIM; row++) {
    for (int col = 0; col < INPUT_DIM; col++) {
      int expected = 0;
      for (int k = 0; k < INPUT_DIM; k++) {
        expected += a[row * INPUT_DIM + k] * b[k * INPUT_DIM + col];
      }
      if (res[row * INPUT_DIM + col] != expected) {
        return false;
      }
    }
  }
  return true;
}

large_matrix transform_into_input(const large_matrix &input) {
  large_matrix res;

  for (int i = 0; i < INPUT_DIM; ++i) {
    for (int j = 0; j < INPUT_DIM; ++j) {
      int tileIndex = (i / TILE_DIM) * (INPUT_DIM / TILE_DIM) + (j / TILE_DIM);
      int indexInTile = (i % TILE_DIM) * TILE_DIM + (j % TILE_DIM);
      res[tileIndex * (TILE_DIM * TILE_DIM) + indexInTile] =
          input[i * INPUT_DIM + j];
    }
  }

  return res;
}

large_matrix transform_into_output(const large_matrix &input) {
  large_matrix res;

  for (int i = 0; i < INPUT_DIM; ++i) {
    for (int j = 0; j < INPUT_DIM; ++j) {
      int tileIndex = (i / TILE_DIM) * (INPUT_DIM / TILE_DIM) + (j / TILE_DIM);
      int indexInTile = (i % TILE_DIM) * TILE_DIM + (j % TILE_DIM);
      res[i * INPUT_DIM + j] =
          input[tileIndex * (TILE_DIM * TILE_DIM) + indexInTile];
    }
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
    if (i % INPUT_DIM == INPUT_DIM - 1)
      std::cout << matrix[i] << "\n";
    else
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

  for (int i = 0; i < INPUT_DIM * INPUT_DIM; i++) {
    mat_a[i] = dist(gen);
    mat_b[i] = dist(gen);
  }

  large_matrix mat_a_t = transform_into_input(mat_a);
  large_matrix mat_b_t = transform_into_input(mat_b);

  print_matrix(mat_a_t);
  print_matrix(mat_b_t);

  if (!write_matrices(fd, mat_a_t, mat_b_t)) {
    return 1;
  }

  if (!start_mul(fd)) {
    return 1;
  }

  wait_for_poll(fd);

  auto res = get_large_result(fd);

  auto res_t = transform_into_output(res);
  print_matrix(res);

  if (verify_result(mat_a, mat_b, res_t)) {
    std::cout << "PASS\n";
  } else {
    std::cout << "FAIL\n";
  }

  close(fd);
  return 0;
}
