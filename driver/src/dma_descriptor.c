#include "dma_descriptor.h"

descriptor create_descriptor(transfer_type_t transfer_type,
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
