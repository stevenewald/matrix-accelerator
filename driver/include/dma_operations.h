#pragma once

#include "dma_descriptor.h"
#include "dma_regs.h"

void block_until_dma_complete(atomic_t *dma_in_progress);

void trigger_dma(mmio_base dma_reg_base, dma_reg_addr_t status_addr,
                 dma_reg_addr_t ctrl_addr);

void execute_dma_transfer(transfer_type_t transfer_type, mmio_base dma_regs,
                          atomic_t *dma_in_progress);

void set_dma_descriptor_addr(transfer_type_t transfer_type, mmio_base dma_regs,
                             dma_addr_t addr);

void configure_dma_interrupts(mmio_base dma_reg_base);
