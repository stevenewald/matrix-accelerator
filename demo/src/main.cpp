#include "api.hpp"
#include "types.hpp"
#include "matrix.hpp"
#include <algorithm>
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

  const matmul_dims dims{11 * 8, 13 * 8, 10 * 8};

  std::cout << "Testing random " << dims.m << "x" << dims.k << " * " << dims.k
            << "x" << dims.n << " mul\n";

  std::random_device rd;
  std::mt19937 gen(rd());
  std::uniform_int_distribution<int16_t> dist(MIN_INPUT_VALUE, MAX_INPUT_VALUE);

  matrix_input mat_a(dims.m * dims.k);
  matrix_input mat_b(dims.k * dims.n);

  uint64_t fpga_dur_exec_ns{};
  uint64_t cpu_dur_exec_ns{};

  for (int j = 0; j < NUM_TRIALS; ++j) {
    for (int i = 0; i < dims.m * dims.k; i++) {
      mat_a[i] = dist(gen);
    }
    for (int i = 0; i < dims.k * dims.n; i++) {
      mat_b[i] = dist(gen);
    }
    matrix_input mat_a_t = transform_into_input_a(mat_a, dims);
    matrix_input mat_b_t = transform_into_input_b(mat_b, dims);

    if (!write_matrices(fd, mat_a_t, mat_b_t)) {
      return 1;
    }

    if (!start_mul(fd, dims)) {
      return 1;
    }

    wait_for_execution_complete(fd);

    auto res = get_large_result(fd, dims);

    int cycles_elapsed = get_cycles_elapsed(fd);
    fpga_dur_exec_ns += 8 * cycles_elapsed; // 125 mhz

    auto res_t = transform_into_output(res, dims);

    auto cpu_start = get_time_ns();
    auto expected = generate_large_result(mat_a, mat_b, dims);
    cpu_dur_exec_ns += get_time_ns() - cpu_start;

    int failed = verify_result(expected, res_t, dims);

    if (failed != 0) {
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
