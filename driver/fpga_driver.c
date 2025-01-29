#include <linux/delay.h>
#include <linux/device.h>
#include <linux/dma-mapping.h>
#include <linux/module.h>
#include <linux/pci.h>
#include <linux/slab.h>
#include <linux/string.h>

#define VENDOR_ID 0x10ee
#define DEVICE_ID 0x7013
#define REG_OFFSET 0x00
#define DMA_BUFFER_SIZE 4096

static void __iomem *bar0_regs;
static void __iomem *bar1_regs;
static dma_addr_t dma_handle;
static void *dma_buffer;
static DEFINE_MUTEX(dma_lock);

typedef struct descriptor {
  uint32_t fst;
  uint32_t len;
  uint32_t src_lo;
  uint32_t src_hi;
  uint32_t dst_lo;
  uint32_t dst_hi;
  uint32_t nxt_lo;
  uint32_t nxt_hi;
} descriptor;

static ssize_t reg_show(struct device *dev, struct device_attribute *attr,
                        char *buf) {
  u32 val = ioread32(bar0_regs + REG_OFFSET);
  return sprintf(buf, "0x%x\n", val);
}

static ssize_t reg_store(struct device *dev, struct device_attribute *attr,
                         const char *buf, size_t count) {
  u32 val;
  if (sscanf(buf, "%x", &val) != 1)
    return -EINVAL;
  iowrite32(val, bar0_regs + REG_OFFSET);
  return count;
}
static DEVICE_ATTR_RW(reg);

static ssize_t dma_write_store(struct device *dev,
                               struct device_attribute *attr, const char *buf,
                               size_t count) {
  size_t bytes = min(count, DMA_BUFFER_SIZE);
  dma_addr_t dma_desc_phys;
  struct descriptor *desc;

  /* Allocate coherent memory for descriptor */
  desc = dma_alloc_coherent(dev, sizeof(*desc), &dma_desc_phys, GFP_KERNEL);
  if (!desc)
    return -ENOMEM;

  memset(desc, 0, sizeof(*desc));
  desc->fst = (0xad4b << 16);// | 1;
  desc->len = bytes;
  desc->src_lo = lower_32_bits(dma_handle);
  desc->src_hi = upper_32_bits(dma_handle);
  desc->dst_lo = 0x0;
  desc->dst_hi = 0x0;

  mutex_lock(&dma_lock);

  dma_sync_single_for_cpu(dev, dma_handle, bytes, DMA_TO_DEVICE);
  memcpy(dma_buffer, buf, bytes);
  dma_sync_single_for_device(dev, dma_handle, bytes, DMA_TO_DEVICE);

  wmb(); 
  iowrite32(lower_32_bits(dma_desc_phys), bar1_regs + 0x4080);
  iowrite32(upper_32_bits(dma_desc_phys), bar1_regs + 0x4084);

  wmb();
  iowrite32(0x4FFFE7F, bar1_regs + 0x04);
  mutex_unlock(&dma_lock);

  udelay(5000);

  dma_free_coherent(dev, sizeof(*desc), desc, dma_desc_phys);
  memset(dma_buffer, 0, DMA_BUFFER_SIZE);
  return bytes;
}

static ssize_t dma_read_show(struct device *dev, struct device_attribute *attr,
                             char *buf) {
  ssize_t ret;

  dma_addr_t dma_desc_phys;
  struct descriptor *desc;

  desc = dma_alloc_coherent(dev, sizeof(*desc), &dma_desc_phys, GFP_KERNEL);
  if (!desc)
    return -ENOMEM;

  memset(desc, 0, sizeof(*desc));
  desc->fst = (0xad4b << 16);// | 1;
  desc->len = 128;
  desc->src_lo = 0x0;
  desc->src_hi = 0x0;
  desc->dst_lo = lower_32_bits(dma_handle);
  desc->dst_hi = upper_32_bits(dma_handle);

  mutex_lock(&dma_lock);

  iowrite32(lower_32_bits(dma_desc_phys), bar1_regs + 0x5080);
  iowrite32(upper_32_bits(dma_desc_phys), bar1_regs + 0x5084);

  iowrite32(0x4FFFE7F, bar1_regs + 0x1004);

  udelay(5000);

  ret = sprintf(buf, "Read buffer: %*ph\n", DMA_BUFFER_SIZE, dma_buffer);
  mutex_unlock(&dma_lock);

  return ret;
}
static DEVICE_ATTR_WO(dma_write);
static DEVICE_ATTR_RO(dma_read);

static irqreturn_t my_interrupt_handler(int irq, void *dev_id) {
  return IRQ_HANDLED;
}

static int my_probe(struct pci_dev *pdev, const struct pci_device_id *id) {
  int ret;

  if (pci_enable_device(pdev))
    return -ENODEV;

  pci_set_master(pdev);

  ret = dma_set_mask_and_coherent(&pdev->dev, DMA_BIT_MASK(32));
  if (ret) {
      dev_err(&pdev->dev, "No suitable DMA mask available\n");
  }

  bar0_regs = pci_iomap(pdev, 0, 0);
  if (!bar0_regs) {
    ret = -ENOMEM;
    goto err_disable_device;
  }

  bar1_regs = pci_iomap(pdev, 1, 0);
  if (!bar1_regs) {
    ret = -ENOMEM;
    goto err_unmap_bar0;
  }

  dma_buffer =
      dma_alloc_coherent(&pdev->dev, DMA_BUFFER_SIZE, &dma_handle, GFP_KERNEL);
  if (!dma_buffer) {
    ret = -ENOMEM;
    goto err_unmap_bar1;
  }

  if (request_irq(pdev->irq, my_interrupt_handler, IRQF_SHARED, "fpga_driver",
                  pdev)) {
    ret = -EBUSY;
    goto err_free_dma;
  }

  if (device_create_file(&pdev->dev, &dev_attr_reg) ||
      device_create_file(&pdev->dev, &dev_attr_dma_write) ||
      device_create_file(&pdev->dev, &dev_attr_dma_read)) {
    ret = -ENOMEM;
    goto err_free_irq;
  }

  return 0;

err_free_irq:
  free_irq(pdev->irq, pdev);
err_free_dma:
  dma_free_coherent(&pdev->dev, DMA_BUFFER_SIZE, dma_buffer, dma_handle);
err_unmap_bar1:
  pci_iounmap(pdev, bar1_regs);
err_unmap_bar0:
  pci_iounmap(pdev, bar0_regs);
err_disable_device:
  pci_disable_device(pdev);
  return ret;
}

static void my_remove(struct pci_dev *pdev) {
  device_remove_file(&pdev->dev, &dev_attr_reg);
  device_remove_file(&pdev->dev, &dev_attr_dma_write);
  device_remove_file(&pdev->dev, &dev_attr_dma_read);
  free_irq(pdev->irq, pdev);
  dma_free_coherent(&pdev->dev, DMA_BUFFER_SIZE, dma_buffer, dma_handle);
  pci_iounmap(pdev, bar0_regs);
  pci_iounmap(pdev, bar1_regs);
  pci_disable_device(pdev);
}

static struct pci_device_id my_device_ids[] = {
    {PCI_DEVICE(VENDOR_ID, DEVICE_ID)},
    {
        0,
    }};
MODULE_DEVICE_TABLE(pci, my_device_ids);

static struct pci_driver my_driver = {
    .name = "fpga_driver",
    .id_table = my_device_ids,
    .probe = my_probe,
    .remove = my_remove,
};
module_pci_driver(my_driver);

MODULE_LICENSE("GPL");
