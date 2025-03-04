#pragma once

#include <linux/cdev.h>

#define DEVICE_NAME "fpga"
#define VENDOR_ID 0x10ee
#define DEVICE_ID 0x7021
#define DMA_BUFFER_SIZE 65536

typedef void __iomem *mmio_base;

struct pcie_dev {
  mmio_base mmio_bar_base, dma_bar_base;
  unsigned long mmio_bar_len, dma_bar_len;
  struct pci_dev *pdev;
  struct cdev cdev;
  dev_t devt;
  struct class *class;
  struct device *device;
  struct mutex dma_lock;
  dma_addr_t dma_handle;
  void *dma_buffer;
  struct completion dma_transfer_done;
  wait_queue_head_t matrix_wait_queue;
  bool matrix_done;
  int dma_irq;
  int usr_irq;
  bool mmio_bar_requested;
  bool dma_bar_requested;
  bool use_dma;
};
