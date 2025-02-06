#include "dma_operations.h"
#include <linux/delay.h>

void block_until_dma_complete(atomic_t *dma_in_progress) {
  while (atomic_read(dma_in_progress)) {
    udelay(5);
  }
}

void trigger_dma(mmio_base dma_reg_base, dma_reg_addr_t status_addr,
                 dma_reg_addr_t ctrl_addr) {
  // Clear stop bit
  static const uint32_t status_reg = 1 << 1;

  // Log everything and start engine
  static const uint32_t ctrl_reg = 0x4FFFE7F;

  write_dma_reg(dma_reg_base, status_addr, status_reg);
  write_dma_reg(dma_reg_base, ctrl_addr, ctrl_reg);
}

void execute_dma_transfer(transfer_type_t transfer_type, mmio_base dma_regs,
                          atomic_t *dma_in_progress) {

  dma_reg_addr_t ctrl_addr = transfer_type.is_h2c ? H2C_CTRL : C2H_CTRL;
  dma_reg_addr_t status_addr = transfer_type.is_h2c ? H2C_STATUS : C2H_STATUS;

  block_until_dma_complete(dma_in_progress);

  // Must be unset by interrupt handler
  atomic_set(dma_in_progress, 1);

  trigger_dma(dma_regs, status_addr, ctrl_addr);

  block_until_dma_complete(dma_in_progress);

  write_dma_reg(dma_regs, ctrl_addr, 0);
}

void set_dma_descriptor_addr(transfer_type_t transfer_type, mmio_base dma_regs,
                             dma_addr_t addr) {
  if (transfer_type.is_h2c) {
    write_dma_reg(dma_regs, H2C_DESCRIPTOR_LOW_ADDR, lower_32_bits(addr));
    write_dma_reg(dma_regs, H2C_DESCRIPTOR_HIGH_ADDR, upper_32_bits(addr));
  } else {
    write_dma_reg(dma_regs, C2H_DESCRIPTOR_LOW_ADDR, lower_32_bits(addr));
    write_dma_reg(dma_regs, C2H_DESCRIPTOR_HIGH_ADDR, upper_32_bits(addr));
  }
}

void configure_dma_interrupts(mmio_base dma_reg_base) {
  // Enable user interrupt 0
  write_dma_reg(dma_reg_base, IRQ_USR_INT_ENABLE, 1);

  // Set user interrupt 0 to MSI vector 0
  write_dma_reg(dma_reg_base, IRQ_USR_VECTOR_NUMBER, 0);

  // Enable interrupts for H2C and C2H
  write_dma_reg(dma_reg_base, IRQ_CHANNEL_INT_ENABLE, 0b11);

  // Set H2C and C2H to MSI vector 1
  write_dma_reg(dma_reg_base, IRQ_CHANNEL_VECTOR_NUMBER, (1 << 8) | 1);

  // Enable interrupt on stop signal
  write_dma_reg(dma_reg_base, H2C_INT_ENABLE, 1 << 1);

  // Enable interrupt on stop signal
  write_dma_reg(dma_reg_base, C2H_INT_ENABLE, 1 << 1);
}
