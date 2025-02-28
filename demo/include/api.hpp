#pragma once
#include "types.hpp"
#include <sys/ioctl.h>
#include <sys/poll.h>
#include <unistd.h>

#define DEVICE_PATH "/dev/fpga"
#define PCIE_SET_DMA (_IOW('k', 1, int))

enum class WriteMode { DMA, MMIO };

void set_write_mode(int fd, WriteMode write_mode);

bool start_mul(int fd, const matmul_dims &dims);

bool write_matrices(int fd, const matrix_input &a, const matrix_input &b);

matrix_res get_large_result(int fd, const matmul_dims &dims);

int get_cycles_elapsed(int fd);

void wait_for_execution_complete(int fd);
