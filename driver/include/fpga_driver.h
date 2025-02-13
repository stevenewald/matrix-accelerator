#pragma once

#include <linux/cdev.h>

#define DEVICE_NAME "fpga"
#define VENDOR_ID 0x10ee
#define DEVICE_ID 0x7013
#define DMA_BUFFER_SIZE 4096

typedef void __iomem *mmio_base;

struct pcie_dev {
  mmio_base bar0_base, bar1_base;
  unsigned long bar0_len, bar1_len;
  struct pci_dev *pdev;
  struct cdev cdev;
  dev_t devt;
  struct class *class;
  struct device *device;
  dma_addr_t dma_handle;
  void *dma_buffer;
  atomic_t dma_in_progress;
  int dma_irq;
  int usr_irq;
  bool bar0_requested;
  bool bar1_requested;
  bool use_dma;
};
