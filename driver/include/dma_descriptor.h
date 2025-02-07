#pragma once
#include <linux/kernel.h>
#include <linux/types.h>

typedef struct {
  bool is_h2c;
} transfer_type_t;

#define H2C ((transfer_type_t){.is_h2c = true})
#define C2H ((transfer_type_t){.is_h2c = false})

typedef struct descriptor {
  uint32_t header;
  uint32_t bytes;
  uint32_t src_lo;
  uint32_t src_hi;
  uint32_t dst_lo;
  uint32_t dst_hi;
  uint32_t nxt_lo;
  uint32_t nxt_hi;
} descriptor;

descriptor create_descriptor(transfer_type_t transfer_type,
                             dma_addr_t host_addr, uint32_t fpga_addr,
                             uint32_t bytes);
