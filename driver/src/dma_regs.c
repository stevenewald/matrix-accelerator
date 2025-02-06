#include "dma_regs.h"

void write_dma_reg(mmio_base dma_cfg_base_addr, dma_reg_addr_t addr,
                   u32 value) {
  iowrite32(value, dma_cfg_base_addr + addr.addr);
}

u32 read_dma_reg(mmio_base dma_cfg_base_addr, dma_reg_addr_t addr) {
  return ioread32(dma_cfg_base_addr + addr.addr);
}
