#pragma once
#include <cmath>
#include <cstdint>
#include <vector>

constexpr std::size_t NUM_TRIALS = 1000;

constexpr std::size_t TILE_DIM = 8;

struct matmul_dims {
  uint16_t m;
  uint16_t k;
  uint16_t n;
};

// Signed
static const int16_t MIN_INPUT_VALUE = -std::pow(2, 15)+1;
static const int16_t MAX_INPUT_VALUE = std::pow(2, 15)-1;

using matrix_input = std::vector<int16_t>;
using matrix_res = std::vector<int32_t>;
