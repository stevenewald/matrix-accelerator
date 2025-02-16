#include "dma_operations.h"
#include <linux/delay.h>
#include <linux/pci.h>

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
                          struct completion *dma_transfer_complete) {

  dma_reg_addr_t ctrl_addr = transfer_type.is_h2c ? H2C_CTRL : C2H_CTRL;
  dma_reg_addr_t status_addr = transfer_type.is_h2c ? H2C_STATUS : C2H_STATUS;

  trigger_dma(dma_regs, status_addr, ctrl_addr);

  wait_for_completion(dma_transfer_complete);

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

size_t dma_write(struct pcie_dev *pcie, const char __user *buf, size_t count,
                 loff_t *ppos) {
  dma_addr_t dma_desc_phys;

  if (*ppos >= DMA_BUFFER_SIZE)
    return 0;

  if (*ppos + count > DMA_BUFFER_SIZE) {
    count = DMA_BUFFER_SIZE - *ppos;
  }

  struct descriptor *desc = dma_alloc_coherent(&pcie->pdev->dev, sizeof(*desc),
                                               &dma_desc_phys, GFP_KERNEL);
  if (!desc)
    return -ENOMEM;

  *desc = create_descriptor(H2C, pcie->dma_handle, *ppos, count);

  mutex_lock(&pcie->dma_lock);

  if (copy_from_user(pcie->dma_buffer, buf, count)) {
    mutex_unlock(&pcie->dma_lock);
    dev_err(pcie->device, "Unable to copy buffer to userspace");
    dma_free_coherent(&pcie->pdev->dev, sizeof(*desc), desc, dma_desc_phys);
    return -EFAULT;
  }
  dma_sync_single_for_device(&pcie->pdev->dev, pcie->dma_handle, count,
                             DMA_TO_DEVICE);

  set_dma_descriptor_addr(H2C, pcie->bar0_base, dma_desc_phys);

  execute_dma_transfer(H2C, pcie->bar0_base, &pcie->dma_transfer_done);

  *ppos += count;
  mutex_unlock(&pcie->dma_lock);
  dma_free_coherent(&pcie->pdev->dev, sizeof(*desc), desc, dma_desc_phys);

  return count;
}
size_t dma_read(struct pcie_dev *pcie, char __user *buf, size_t count,
                loff_t *ppos) {
  dma_addr_t dma_desc_phys;

  if (*ppos >= DMA_BUFFER_SIZE)
    return 0;

  if (*ppos + count > DMA_BUFFER_SIZE)
    count = DMA_BUFFER_SIZE - *ppos;

  struct descriptor *desc = dma_alloc_coherent(&pcie->pdev->dev, sizeof(*desc),
                                               &dma_desc_phys, GFP_KERNEL);
  if (!desc)
    return -ENOMEM;

  *desc = create_descriptor(C2H, pcie->dma_handle, *ppos, count);

  mutex_lock(&pcie->dma_lock);

  set_dma_descriptor_addr(C2H, pcie->bar0_base, dma_desc_phys);

  execute_dma_transfer(C2H, pcie->bar0_base, &pcie->dma_transfer_done);

  dma_sync_single_for_cpu(&pcie->pdev->dev, pcie->dma_handle, count,
                          DMA_FROM_DEVICE);

  if (copy_to_user(buf, pcie->dma_buffer, count)) {
    dev_err(pcie->device, "Unable to copy buffer to userspace");
    mutex_unlock(&pcie->dma_lock);
    dma_free_coherent(&pcie->pdev->dev, sizeof(*desc), desc, dma_desc_phys);
    return -EFAULT;
  }

  *ppos += count;
  mutex_unlock(&pcie->dma_lock);
  dma_free_coherent(&pcie->pdev->dev, sizeof(*desc), desc, dma_desc_phys);

  return count;
}
