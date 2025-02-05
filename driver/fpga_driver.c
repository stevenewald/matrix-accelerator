#include <linux/cdev.h>
#include <linux/delay.h>
#include <linux/device.h>
#include <linux/dma-mapping.h>
#include <linux/module.h>
#include <linux/pci.h>
#include <linux/slab.h>
#include <linux/string.h>

#define DEVICE_NAME "fpga"
#define VENDOR_ID 0x10ee
#define DEVICE_ID 0x7013
#define REG_OFFSET 0x00
#define DMA_BUFFER_SIZE 4096

struct pcie_dev {
  void __iomem *bar0_base, *bar1_base;
  unsigned long bar0_len, bar1_len;
  struct pci_dev *pdev;
  struct cdev cdev;
  dev_t devt;
  struct class *class;
  struct device *device;
  dma_addr_t dma_handle;
  void *dma_buffer;
  int irq;
};

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

static loff_t pcie_llseek(struct file *file, loff_t offset, int whence) {
  loff_t new_pos;

  switch (whence) {
  case SEEK_SET:
    new_pos = offset;
    break;
  case SEEK_CUR:
    new_pos = file->f_pos + offset;
    break;
  case SEEK_END:
    new_pos = DMA_BUFFER_SIZE + offset;
    break;
  default:
    return -EINVAL;
  }

  if (new_pos < 0 || new_pos > DMA_BUFFER_SIZE)
    return -EINVAL; // Out of bounds

  file->f_pos = new_pos;
  return new_pos;
}

static ssize_t pcie_dma_write(struct file *filp, const char __user *buf,
                              size_t count, loff_t *ppos) {
  struct pcie_dev *pcie = filp->private_data;
  dma_addr_t dma_desc_phys;
  struct descriptor *desc;

  if (*ppos >= DMA_BUFFER_SIZE)
    return 0;

  if (*ppos + count > DMA_BUFFER_SIZE) {
    printk("Write size too large\n");
    count = DMA_BUFFER_SIZE - *ppos;
  }

  desc = dma_alloc_coherent(&pcie->pdev->dev, sizeof(*desc), &dma_desc_phys,
                            GFP_KERNEL);
  if (!desc)
    return -ENOMEM;

  memset(desc, 0, sizeof(*desc));
  desc->fst = (0xad4b << 16) | (1 << 1);
  desc->len = count;
  desc->src_lo = lower_32_bits(pcie->dma_handle);
  desc->src_hi = upper_32_bits(pcie->dma_handle);
  desc->dst_lo = *ppos;
  desc->dst_hi = 0x0;

  mutex_lock(&dma_lock);

  dma_sync_single_for_cpu(&pcie->pdev->dev, pcie->dma_handle, count,
                          DMA_TO_DEVICE);
  if (copy_from_user(pcie->dma_buffer, buf, count)) {
    mutex_unlock(&dma_lock);
    dev_err(pcie->device, "Unable to copy buffer to userspace");
    dma_free_coherent(&pcie->pdev->dev, sizeof(*desc), desc, dma_desc_phys);
    return -EFAULT;
  }
  dma_sync_single_for_device(&pcie->pdev->dev, pcie->dma_handle, count,
                             DMA_TO_DEVICE);

  wmb();
  iowrite32(lower_32_bits(dma_desc_phys), pcie->bar1_base + 0x4080);
  iowrite32(upper_32_bits(dma_desc_phys), pcie->bar1_base + 0x4084);

  wmb();
  iowrite32(0x4FFFE7F, pcie->bar1_base + 0x04);
  mutex_unlock(&dma_lock);

  // todo: replace with interrupts
  while (ioread32(pcie->bar1_base + 0x4) & 1) {
  }

  dma_free_coherent(&pcie->pdev->dev, sizeof(*desc), desc, dma_desc_phys);
  memset(pcie->dma_buffer, 0, DMA_BUFFER_SIZE);
  *ppos += count;

  return count;
}

static ssize_t pcie_dma_read(struct file *file, char __user *buf, size_t count,
                             loff_t *ppos) {
  struct pcie_dev *pcie = file->private_data;
  dma_addr_t dma_desc_phys;
  struct descriptor *desc;

  if (*ppos >= DMA_BUFFER_SIZE)
    return 0;

  if (*ppos + count > DMA_BUFFER_SIZE)
    count = DMA_BUFFER_SIZE - *ppos;

  desc = dma_alloc_coherent(&pcie->pdev->dev, sizeof(*desc), &dma_desc_phys,
                            GFP_KERNEL);
  if (!desc)
    return -ENOMEM;

  memset(desc, 0, sizeof(*desc));
  desc->fst = (0xad4b << 16);
  desc->len = count;
  desc->src_lo = *ppos;
  desc->src_hi = 0x0;
  desc->dst_lo = lower_32_bits(pcie->dma_handle);
  desc->dst_hi = upper_32_bits(pcie->dma_handle);

  mutex_lock(&dma_lock);

  iowrite32(lower_32_bits(dma_desc_phys), pcie->bar1_base + 0x5080);
  iowrite32(upper_32_bits(dma_desc_phys), pcie->bar1_base + 0x5084);
  iowrite32(0x4FFFE7F, pcie->bar1_base + 0x1004);

  // todo: replace with interrupts
  while (ioread32(pcie->bar1_base + 0x1004) & 1) {
  }

  if (copy_to_user(buf, pcie->dma_buffer, count)) {
    dev_err(pcie->device, "Unable to copy buffer to userspace");
    mutex_unlock(&dma_lock);
    dma_free_coherent(&pcie->pdev->dev, sizeof(*desc), desc, dma_desc_phys);
    return -EFAULT;
  }

  mutex_unlock(&dma_lock);
  dma_free_coherent(&pcie->pdev->dev, sizeof(*desc), desc, dma_desc_phys);

  *ppos += count;
  return count;
}

static irqreturn_t pcie_interrupt_handler(int irq, void *dev_id) {
  printk("MSI interrupt received on IRQ %d\n", irq);
  return IRQ_HANDLED;
}

static int pcie_open(struct inode *inode, struct file *filp) {

  struct pcie_dev *pcie = container_of(inode->i_cdev, struct pcie_dev, cdev);
  filp->private_data = pcie;
  return 0;
}

static int pcie_release(struct inode *inode, struct file *filp) {
  struct pcie_dev *pcie = filp->private_data;

  dev_info(&pcie->pdev->dev, "Device closed\n");
  return 0;
}

static struct file_operations pcie_fops = {.owner = THIS_MODULE,
                                           .open = pcie_open,
                                           .release = pcie_release,
                                           .read = pcie_dma_read,
                                           .write = pcie_dma_write,
                                           .llseek = pcie_llseek};

// DRIVER OPS

static int pcie_probe(struct pci_dev *pdev, const struct pci_device_id *id) {
  dev_info(&pdev->dev, "Initializing PCIe probe");
  struct pcie_dev *dev;
  int ret;

  dev = devm_kzalloc(&pdev->dev, sizeof(*dev), GFP_KERNEL);
  if (!dev)
    return -ENOMEM;

  dev->pdev = pdev;

  if (pci_enable_device(pdev))
    return -ENODEV;

  if (pci_request_region(pdev, 0, "MMIO Interface")) {
    dev_err(&pdev->dev, "Failed to request BAR0");
    ret = -ENODEV;
    goto err_disable_device;
  }

  if (pci_request_region(pdev, 1, "DMA Interface")) {
    dev_err(&pdev->dev, "Failed to request BAR1");
    ret = -ENODEV;
    goto err_release_bar0;
  }

  pci_set_master(pdev);

  dev->bar0_len = pci_resource_len(pdev, 0);
  dev_info(&pdev->dev, "Detected bar0 with size %ld\n", dev->bar0_len);
  dev->bar0_base = pci_iomap(pdev, 0, dev->bar0_len);
  if (!dev->bar0_base) {
    dev_err(&pdev->dev, "Failed to register bar0");
    ret = -ENOMEM;
    goto err_release_bar1;
  }

  dev->bar1_len = pci_resource_len(pdev, 1);
  dev_info(&pdev->dev, "Detected bar1 with size %ld\n", dev->bar1_len);
  dev->bar1_base = pci_iomap(pdev, 1, dev->bar1_len);
  if (!dev->bar1_base) {
    dev_err(&pdev->dev, "Failed to register bar1");
    ret = -ENOMEM;
    goto err_unmap_bar0;
  }

  ret = dma_set_mask_and_coherent(&pdev->dev, DMA_BIT_MASK(32));
  if (ret) {
    dev_err(&pdev->dev, "No suitable DMA mask available\n");
    goto err_unmap_bar1;
  }

  dev->dma_buffer = dma_alloc_coherent(&pdev->dev, DMA_BUFFER_SIZE,
                                       &dev->dma_handle, GFP_KERNEL);
  if (!dev->dma_buffer) {
    dev_err(&pdev->dev, "Unable to allocate DMA buffer");
    ret = -ENOMEM;
    goto err_unmap_bar1;
  }

  if (pci_alloc_irq_vectors(pdev, 1, 1, PCI_IRQ_MSI) != 1) {
    dev_err(&pdev->dev, "Failed to allocate MSI vector");
    goto err_free_dma;
  }

  dev->irq = pci_irq_vector(pdev, 0);

  if (request_irq(pdev->irq, pcie_interrupt_handler, 0, "fpga_driver", pdev)) {
    dev_err(&pdev->dev, "Unable to request IRQ");
    ret = -EBUSY;
    goto err_free_irq_errors;
  }

  iowrite32(0x1, dev->bar1_base + 0x2004); //enable user interrupts

  alloc_chrdev_region(&dev->devt, 0, 1, DEVICE_NAME);
  cdev_init(&dev->cdev, &pcie_fops);
  cdev_add(&dev->cdev, dev->devt, 1);

  dev->class = class_create(DEVICE_NAME);
  dev->device = device_create(dev->class, NULL, dev->devt, NULL, DEVICE_NAME);

  pci_set_drvdata(pdev, dev);
  printk("FPGA Driver Loaded Successfully");
  return 0;

err_free_irq_errors:
  pci_free_irq_vectors(pdev);
err_free_dma:
  dma_free_coherent(&pdev->dev, DMA_BUFFER_SIZE, dev->dma_buffer,
                    dev->dma_handle);
err_unmap_bar1:
  pci_iounmap(pdev, dev->bar1_base);
err_unmap_bar0:
  pci_iounmap(pdev, dev->bar0_base);
err_release_bar1:
  pci_release_region(pdev, 1);
err_release_bar0:
  pci_release_region(pdev, 0);
err_disable_device:
  pci_disable_device(pdev);
  return ret;
}

static void pcie_remove(struct pci_dev *pdev) {
  struct pcie_dev *dev = pci_get_drvdata(pdev);
  dev_info(dev->device, "Removing pcie driver");
  device_destroy(dev->class, dev->devt);
  cdev_del(&dev->cdev);
  class_destroy(dev->class);
  unregister_chrdev_region(dev->devt, 1);

  free_irq(pdev->irq, pdev);
  pci_free_irq_vectors(pdev);
  dma_free_coherent(&pdev->dev, DMA_BUFFER_SIZE, dev->dma_buffer,
                    dev->dma_handle);
  pci_iounmap(pdev, dev->bar1_base);
  pci_iounmap(pdev, dev->bar0_base);
  pci_release_region(pdev, 1);
  pci_release_region(pdev, 0);
  pci_disable_device(pdev);
}

static struct pci_device_id pcie_device_ids[] = {
    {PCI_DEVICE(VENDOR_ID, DEVICE_ID)},
    {
        0,
    }};
MODULE_DEVICE_TABLE(pci, pcie_device_ids);

static struct pci_driver pcie_driver = {
    .name = "fpga_driver",
    .id_table = pcie_device_ids,
    .probe = pcie_probe,
    .remove = pcie_remove,
};
module_pci_driver(pcie_driver);

MODULE_LICENSE("GPL");
