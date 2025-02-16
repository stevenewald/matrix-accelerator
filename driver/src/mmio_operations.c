#include "mmio_operations.h"
#include <linux/io.h>

size_t mmio_read(struct pcie_dev *pcie, char __user *buf, size_t count,
                 loff_t *ppos) {
  void __iomem *mmio_base;
  char kbuf[256];
  size_t read_size = min(count, sizeof(kbuf));

  if (!pcie || !pcie->bar0_base || !buf || !ppos)
    return -EINVAL;

  mmio_base = pcie->bar0_base + *ppos;

  memcpy_fromio(kbuf, mmio_base, read_size);

  if (copy_to_user(buf, kbuf, read_size))
    return -EFAULT;

  *ppos += read_size;
  return read_size;
}

size_t mmio_write(struct pcie_dev *pcie, const char __user *buf, size_t count,
                  loff_t *ppos) {
  size_t written = 0;
  size_t offset = *ppos;

  if (!pcie || !pcie->bar0_base || !buf || offset >= pcie->bar0_len) {
    return -EINVAL;
  }

  if (offset + count > pcie->bar0_len) {
    count = pcie->bar0_len - offset;
  }

  while (written < count) {
    size_t remaining = count - written;
    u32 val;

    if (remaining >= 4) {
      if (copy_from_user(&val, buf + written, 4))
        return -EFAULT;
      writel(val, pcie->bar0_base + offset + written);
      written += 4;
    } else {
      u8 temp[4] = {0};
      if (copy_from_user(temp, buf + written, remaining))
        return -EFAULT;

      val = *(u32 *)temp;
      writel(val, pcie->bar0_base + offset + written);
      written += remaining;
    }
  }

  *ppos += written;
  return written;
}
