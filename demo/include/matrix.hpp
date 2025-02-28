#pragma once
#include "types.hpp"

matrix_res generate_large_result(const matrix_input &a, const matrix_input &b,
                                 const matmul_dims &dims);

matrix_input transform_into_input_a(const matrix_input &input,
                                    const matmul_dims &dims);

matrix_input transform_into_input_b(const matrix_input &input,
                                    const matmul_dims &dims);

matrix_res transform_into_output(const matrix_res &input,
                                 const matmul_dims &dims);

int verify_result(const matrix_res &a, const matrix_res &b,
                  const matmul_dims &dims);
