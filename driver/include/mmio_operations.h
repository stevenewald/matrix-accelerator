#pragma once
#include "fpga_driver.h"

size_t mmio_write(struct pcie_dev *pcie, const char __user *buf, size_t count,
                  loff_t *ppos);
size_t mmio_read(struct pcie_dev *pcie, char __user *buf, size_t count,
                 loff_t *ppos);
