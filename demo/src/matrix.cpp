#include "matrix.hpp"
#include <iostream>

matrix_res generate_large_result(const matrix_input &a, const matrix_input &b,
                                 const matmul_dims &dims) {
  matrix_res res(dims.m * dims.n);
  for (int row = 0; row < dims.m; row++) {
    for (int col = 0; col < dims.n; col++) {
      for (int k = 0; k < dims.k; k++) {
        res[row * dims.n + col] +=
            int32_t(a[row * dims.k + k]) * int32_t(b[k * dims.n + col]);
      }
    }
  }
  return res;
}

matrix_input transform_into_input_a(const matrix_input &input,
                                    const matmul_dims &dims) {
  matrix_input res(dims.m * dims.k);

  for (int i = 0; i < dims.m; ++i) {
    for (int j = 0; j < dims.k; ++j) {
      int tileIndex = (i / TILE_DIM) * (dims.k / TILE_DIM) + (j / TILE_DIM);
      int indexInTile = (i % TILE_DIM) * TILE_DIM + (j % TILE_DIM);
      res[tileIndex * (TILE_DIM * TILE_DIM) + indexInTile] =
          input[i * dims.k + j];
    }
  }

  return res;
}

matrix_input transform_into_input_b(const matrix_input &input,
                                    const matmul_dims &dims) {
  matrix_input res(dims.k * dims.n);

  for (int i = 0; i < dims.k; ++i) {
    for (int j = 0; j < dims.n; ++j) {
      int tileIndex = (i / TILE_DIM) * (dims.n / TILE_DIM) + (j / TILE_DIM);
      int indexInTile = (i % TILE_DIM) * TILE_DIM + (j % TILE_DIM);
      res[tileIndex * (TILE_DIM * TILE_DIM) + indexInTile] =
          input[i * dims.n + j];
    }
  }
  return res;
}

matrix_res transform_into_output(const matrix_res &input,
                                 const matmul_dims &dims) {
  matrix_res res(dims.m * dims.n);

  for (int i = 0; i < dims.m; ++i) {
    for (int j = 0; j < dims.n; ++j) {
      int tileIndex = (i / TILE_DIM) * (dims.n / TILE_DIM) + (j / TILE_DIM);
      int indexInTile = (i % TILE_DIM) * TILE_DIM + (j % TILE_DIM);
      res[i * dims.n + j] =
          input[tileIndex * (TILE_DIM * TILE_DIM) + indexInTile];
    }
  }

  return res;
}

int verify_result(const matrix_res &a, const matrix_res &b,
                  const matmul_dims &dims) {
  int failed = 0;
  for (int row = 0; row < dims.m; row++) {
    for (int col = 0; col < dims.n; col++) {
      if (a[row * dims.n + col] != b[row * dims.n + col]) {
        std::cout << (row * dims.n + col) << ", "
                  << 4 * (1 + dims.m * dims.k + row * dims.n + col) << ", "
                  << (a[row * dims.n + col]) << "~=" << (b[row * dims.n + col])
                  << "\n";
        ++failed;
      }
    }
  }
  return failed;
}
