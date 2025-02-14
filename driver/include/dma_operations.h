#pragma once

#include "dma_descriptor.h"
#include "dma_regs.h"
#include "fpga_driver.h"

void trigger_dma(mmio_base dma_reg_base, dma_reg_addr_t status_addr,
                 dma_reg_addr_t ctrl_addr);

void execute_dma_transfer(transfer_type_t transfer_type, mmio_base dma_regs,
                          struct completion *dma_transfer_complete);

void set_dma_descriptor_addr(transfer_type_t transfer_type, mmio_base dma_regs,
                             dma_addr_t addr);

void configure_dma_interrupts(mmio_base dma_reg_base);

size_t dma_write(struct pcie_dev *pcie, const char __user *buf, size_t count,
                 loff_t *ppos);
size_t dma_read(struct pcie_dev *pcie, char __user *buf, size_t count,
                loff_t *ppos);
