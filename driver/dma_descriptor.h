#pragma once
#include <linux/types.h>
#include <linux/kernel.h>

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

inline descriptor create_descriptor(transfer_type_t transfer_type,
                                    dma_addr_t host_addr, uint32_t fpga_addr,
                                    uint32_t bytes) {
  descriptor desc = {0};

  uint32_t magic = 0xad4b << 16;
  uint32_t stop_on_complete = 1;
  desc.header = magic | stop_on_complete;

  if (transfer_type.is_h2c) {
    desc.src_lo = lower_32_bits(host_addr);
    desc.src_hi = upper_32_bits(host_addr);
    desc.dst_lo = fpga_addr;
    desc.dst_hi = 0; // 32 bit addressing on card
  } else {
    desc.src_lo = fpga_addr;
    desc.src_hi = 0; // 32 bit addressing on card
    desc.dst_lo = lower_32_bits(host_addr);
    desc.dst_hi = upper_32_bits(host_addr);
  }

  desc.bytes = bytes;

  return desc;
}
