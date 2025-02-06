#pragma once

#include "util.h"
#include <linux/dma-mapping.h>
#include <linux/types.h>

typedef struct {
  u32 addr;
} dma_reg_addr_t;

#define H2C_CTRL ((dma_reg_addr_t){.addr = 0x0004})
#define H2C_STATUS ((dma_reg_addr_t){.addr = 0x0040})
#define H2C_INT_ENABLE ((dma_reg_addr_t){.addr = 0x0090})

#define C2H_CTRL ((dma_reg_addr_t){.addr = 0x1004})
#define C2H_STATUS ((dma_reg_addr_t){.addr = 0x1040})
#define C2H_INT_ENABLE ((dma_reg_addr_t){.addr = 0x1090})

#define IRQ_USR_INT_ENABLE ((dma_reg_addr_t){.addr = 0x2004})
#define IRQ_CHANNEL_INT_ENABLE ((dma_reg_addr_t){.addr = 0x2010})
#define IRQ_USR_VECTOR_NUMBER ((dma_reg_addr_t){.addr = 0x2080})
#define IRQ_CHANNEL_VECTOR_NUMBER ((dma_reg_addr_t){.addr = 0x20A0})

#define H2C_DESCRIPTOR_LOW_ADDR ((dma_reg_addr_t){.addr = 0x4080})
#define H2C_DESCRIPTOR_HIGH_ADDR ((dma_reg_addr_t){.addr = 0x4084})

#define C2H_DESCRIPTOR_LOW_ADDR ((dma_reg_addr_t){.addr = 0x5080})
#define C2H_DESCRIPTOR_HIGH_ADDR ((dma_reg_addr_t){.addr = 0x5084})

inline void write_dma_reg(mmio_base dma_cfg_base_addr, dma_reg_addr_t addr,
                          u32 value) {
  iowrite32(value, dma_cfg_base_addr + addr.addr);
}

inline u32 read_dma_reg(mmio_base dma_cfg_base_addr, dma_reg_addr_t addr) {
  return ioread32(dma_cfg_base_addr + addr.addr);
}
