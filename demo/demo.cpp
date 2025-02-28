#include <algorithm>
#include <array>
#include <cassert>
#include <cstdint>
#include <cstring>
#include <fcntl.h>
#include <iostream>
#include <random>
#include <sys/ioctl.h>
#include <sys/poll.h>
#include <unistd.h>
#include <x86intrin.h>

#define NUM_TRIALS 300

#define TILE_DIM 8

// Signed
#define MIN_INPUT_VALUE -std::pow(2, 14)
#define MAX_INPUT_VALUE std::pow(2, 14)

#define INPUT_TILES_M 11
#define INPUT_TILES_K 13
#define INPUT_TILES_N 10

#define INPUT_DIM_M (8*INPUT_TILES_M)
#define INPUT_DIM_K (8*INPUT_TILES_K)
#define INPUT_DIM_N (8*INPUT_TILES_N)

#define DEVICE_PATH "/dev/fpga"
#define PCIE_SET_DMA (_IOW('k', 1, int))

using large_matrix_a = std::array<int16_t, INPUT_DIM_M * INPUT_DIM_K>;
using large_matrix_b = std::array<int16_t, INPUT_DIM_K * INPUT_DIM_N>;
using large_matrix_res = std::array<int32_t, INPUT_DIM_M * INPUT_DIM_N>;

static_assert(32 + sizeof(large_matrix_a) + sizeof(large_matrix_b) +
                  sizeof(large_matrix_res) <=
              65535);
static_assert(INPUT_DIM_M%8==0);
static_assert(INPUT_DIM_K%8==0);
static_assert(INPUT_DIM_N%8==0);

void set_write_mode(int fd, int dma_on) {
  if (ioctl(fd, PCIE_SET_DMA, &dma_on) < 0) {
    perror("ioctl failed");
  }
}

bool start_mul(int fd) {
  set_write_mode(fd, false);
  int arg = (INPUT_DIM_N << 20) | (INPUT_DIM_K << 10) | (INPUT_DIM_M);
  if (pwrite(fd, &arg, 1 * sizeof(int), 0) != 1 * sizeof(int)) {
    std::cerr << "matrix start mul failed" << std::endl;
    return false;
  }
  return true;
}

bool write_matrices(int fd, const large_matrix_a &a, const large_matrix_b &b) {
  set_write_mode(fd, true);
  std::vector<int16_t> args(INPUT_DIM_M * INPUT_DIM_K +
                            INPUT_DIM_K * INPUT_DIM_N);
  std::copy(a.begin(), a.end(), args.begin());
  std::copy(b.begin(), b.end(), args.begin() + INPUT_DIM_M * INPUT_DIM_K);

  off_t offset = 32;
  ssize_t bytes_written =
      pwrite(fd, args.data(), args.size() * sizeof(int16_t), offset);
  if (bytes_written != args.size() * sizeof(int16_t)) {
    std::cerr << "large_matrix pwrite failed" << std::endl;
    close(fd);
    return false;
  }
  return true;
}

large_matrix_res get_large_result(int fd) {
  set_write_mode(fd, true);
  large_matrix_res res;
  off_t offset =
      32 + 2 * (INPUT_DIM_M * INPUT_DIM_K + INPUT_DIM_K * INPUT_DIM_N);
  ssize_t bytes_read =
      pread(fd, res.data(), res.size() * sizeof(int32_t), offset);
  if (bytes_read != res.size() * sizeof(int32_t)) {
    std::cerr << "pread failed, read " << bytes_read << " bytes instead of "
              << INPUT_DIM_M * INPUT_DIM_N * 4 << std::endl;
    close(fd);
    throw std::runtime_error("Failed to read result large_matrix");
  }
  return res;
}

int get_cycles_elapsed(int fd) {
  set_write_mode(fd, true);
  int32_t res;
  off_t offset = 4;
  ssize_t bytes_read = pread(fd, &res, sizeof(int32_t), offset);
  if (bytes_read != sizeof(int32_t)) {
    std::cerr << "pread failed, read " << bytes_read << " bytes instead of "
              << sizeof(int32_t) << "bytes\n";
    close(fd);
    throw std::runtime_error("Failed to read result large_matrix");
  }
  return res;
}

large_matrix_res generate_large_result(const large_matrix_a &a,
                                       const large_matrix_b &b) {
  large_matrix_res res{};
  for (int row = 0; row < INPUT_DIM_M; row++) {
    for (int col = 0; col < INPUT_DIM_N; col++) {
      for (int k = 0; k < INPUT_DIM_K; k++) {
        res[row * INPUT_DIM_N + col] += int32_t(a[row * INPUT_DIM_K + k]) *
                                        int32_t(b[k * INPUT_DIM_N + col]);
      }
    }
  }
  return res;
}

int verify_result(const large_matrix_res &a, const large_matrix_res &b) {
  int failed = 0;
  for (int row = 0; row < INPUT_DIM_M; row++) {
    for (int col = 0; col < INPUT_DIM_N; col++) {
      if (a[row * INPUT_DIM_N + col] != b[row * INPUT_DIM_N + col]) {
        std::cout << (row * INPUT_DIM_N + col) << ", "
                  << 4 * (1 + INPUT_DIM_M * INPUT_DIM_K + row * INPUT_DIM_N +
                          col)
                  << ", " << (a[row * INPUT_DIM_N + col])
                  << "~=" << (b[row * INPUT_DIM_N + col]) << "\n";
        ++failed;
      }
    }
  }
  return failed;
}

large_matrix_a transform_into_input_a(const large_matrix_a &input) {
  large_matrix_a res;

  for (int i = 0; i < INPUT_DIM_M; ++i) {
    for (int j = 0; j < INPUT_DIM_K; ++j) {
      int tileIndex =
          (i / TILE_DIM) * (INPUT_DIM_K / TILE_DIM) + (j / TILE_DIM);
      int indexInTile = (i % TILE_DIM) * TILE_DIM + (j % TILE_DIM);
      res[tileIndex * (TILE_DIM * TILE_DIM) + indexInTile] =
          input[i * INPUT_DIM_K + j];
    }
  }

  return res;
}

large_matrix_b transform_into_input_b(const large_matrix_b &input) {
  large_matrix_b res;

  for (int i = 0; i < INPUT_DIM_K; ++i) {
    for (int j = 0; j < INPUT_DIM_N; ++j) {
      int tileIndex =
          (i / TILE_DIM) * (INPUT_DIM_N / TILE_DIM) + (j / TILE_DIM);
      int indexInTile = (i % TILE_DIM) * TILE_DIM + (j % TILE_DIM);
      res[tileIndex * (TILE_DIM * TILE_DIM) + indexInTile] =
          input[i * INPUT_DIM_N + j];
    }
  }
  return res;
}

large_matrix_res transform_into_output(const large_matrix_res &input) {
  large_matrix_res res;

  for (int i = 0; i < INPUT_DIM_M; ++i) {
    for (int j = 0; j < INPUT_DIM_N; ++j) {
      int tileIndex =
          (i / TILE_DIM) * (INPUT_DIM_N / TILE_DIM) + (j / TILE_DIM);
      int indexInTile = (i % TILE_DIM) * TILE_DIM + (j % TILE_DIM);
      res[i * INPUT_DIM_N + j] =
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

void print_matrix(const large_matrix_a &matrix) {
  for (int i = 0; i < matrix.size(); ++i) {
    if (i % INPUT_DIM_M == INPUT_DIM_M - 1)
      std::cout << matrix[i] << "\n";
    else
      std::cout << matrix[i] << " ";
  }
  std::cout << "\n\n";
}

uint64_t get_time_ns() {
  struct timespec ts;
  clock_gettime(CLOCK_THREAD_CPUTIME_ID, &ts);
  return ts.tv_sec * 1'000'000'000LL + ts.tv_nsec;
}

int main() {
  int fd = open(DEVICE_PATH, O_RDWR);
  if (fd < 0) {
    std::cerr << "Failed to open " << DEVICE_PATH << std::endl;
    return 1;
  }

  std::cout << "Testing random " << INPUT_DIM_M << "x" << INPUT_DIM_K << " * "
            << INPUT_DIM_K << "x" << INPUT_DIM_N << " mul\n";

  std::random_device rd;
  std::mt19937 gen(rd());
  std::uniform_int_distribution<int16_t> dist(MIN_INPUT_VALUE, MAX_INPUT_VALUE);

  large_matrix_a mat_a;
  large_matrix_b mat_b;

  uint64_t fpga_dur_exec_ns{};
  uint64_t cpu_dur_exec_ns{};

  for (int j = 0; j < NUM_TRIALS; ++j) {
    for (int i = 0; i < INPUT_DIM_M * INPUT_DIM_K; i++) {
      mat_a[i] = dist(gen);
    }
    for (int i = 0; i < INPUT_DIM_K * INPUT_DIM_N; i++) {
      mat_b[i] = dist(gen);
    }
    large_matrix_a mat_a_t = transform_into_input_a(mat_a);
    large_matrix_b mat_b_t = transform_into_input_b(mat_b);

    if (!write_matrices(fd, mat_a_t, mat_b_t)) {
      return 1;
    }

    if (!start_mul(fd)) {
      return 1;
    }

    wait_for_poll(fd);

    auto res = get_large_result(fd);

    int cycles_elapsed = get_cycles_elapsed(fd);
    fpga_dur_exec_ns += 8 * cycles_elapsed; // 125 mhz

    auto res_t = transform_into_output(res);

    auto cpu_start = get_time_ns();
    auto expected = generate_large_result(mat_a, mat_b);
    cpu_dur_exec_ns += get_time_ns() - cpu_start;

    int failed = verify_result(expected, res_t);

    if (failed != 0) {
      // print_matrix(res);
      std::cout << "FAILED " << failed << " VALUES\n";
      break;
    }
    if (j % std::max(int(.05f * NUM_TRIALS), 1) == 0) {
      std::cout << float(j) / NUM_TRIALS << "\n";
    }
    if (j == NUM_TRIALS - 1) {
      std::cout << "PASS.\n\n";

      std::cout << "FPGA exec ms: "
                << (double(fpga_dur_exec_ns) / NUM_TRIALS) / 1000000 << "ms\n";
      std::cout << "CPU exec ms: "
                << (double(cpu_dur_exec_ns) / NUM_TRIALS) / 1000000 << "ms\n";

      std::cout << "\n";

      uint64_t cpu_cycles = double(cpu_dur_exec_ns) / .277778;
      uint64_t fpga_cycles = double(fpga_dur_exec_ns) / 8;

      std::cout << "FPGA exec cycles: " << fpga_cycles / NUM_TRIALS << "\n";
      std::cout << "CPU exec cycles: " << cpu_cycles / NUM_TRIALS << "\n";

      std::cout << "\n";
      std::cout << "Time Speedup: "
                << double(cpu_dur_exec_ns) / fpga_dur_exec_ns << "\n";
      std::cout << "Cycle Speedup: " << double(cpu_cycles) / fpga_cycles
                << "\n";
    }
  }

  close(fd);
  return 0;
}
