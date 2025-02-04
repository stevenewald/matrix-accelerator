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

static dev_t dev_num;
static struct cdev pcie_cdev;
static struct class *pcie_class;

static void __iomem *bar0_base, *bar1_base;
static size_t bar0_size, bar1_size;

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

#define REG_SIZE 4

static ssize_t pcie_reg_read(struct file *file, char __user *buf, size_t count, loff_t *ppos) {
    u32 val;

    if (*ppos != 0)  
        return 0;

    val = ioread32(bar0_base + REG_OFFSET);

    if (copy_to_user(buf, &val, sizeof(val)))
        return -EFAULT;

    *ppos += sizeof(val);
    return sizeof(val);
}

static ssize_t pcie_reg_write(struct file *file, const char __user *buf, size_t count, loff_t *ppos) {
    u32 val;

    if (count < sizeof(val))
        return -EINVAL;

    if (copy_from_user(&val, buf, sizeof(val)))
        return -EFAULT;

    iowrite32(val, bar0_base + REG_OFFSET);

    return sizeof(val);
}

static irqreturn_t pcie_interrupt_handler(int irq, void *dev_id) {
  return IRQ_HANDLED;
}

static int pcie_open(struct inode *inode, struct file *filp) { return 0; }

static int pcie_release(struct inode *inode, struct file *filp) { return 0; }
static struct file_operations pcie_fops = {
    .owner = THIS_MODULE, .open = pcie_open, .release = pcie_release,
    .read = pcie_reg_read,
    .write = pcie_reg_write,
};

// DRIVER OPS

static int pcie_probe(struct pci_dev *pdev, const struct pci_device_id *id) {
  printk("Initializing PCIe probe");
  int ret;

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

  bar0_size = pci_resource_len(pdev, 0);
  printk("Detected bar0 with size %ld\n", bar0_size);
  bar0_base = pci_iomap(pdev, 0, bar0_size);
  if (!bar0_base) {
    dev_err(&pdev->dev, "Failed to register bar0");
    ret = -ENOMEM;
    goto err_release_bar1;
  }

  bar1_size = pci_resource_len(pdev, 1);
  printk("Detected bar1 with size %ld\n", bar1_size);
  bar1_base = pci_iomap(pdev, 1, bar1_size);
  if (!bar1_base) {
    dev_err(&pdev->dev, "Failed to register bar1");
    ret = -ENOMEM;
    goto err_unmap_bar0;
  }

  ret = dma_set_mask_and_coherent(&pdev->dev, DMA_BIT_MASK(32));
  if (ret) {
    dev_err(&pdev->dev, "No suitable DMA mask available\n");
    goto err_unmap_bar1;
  }

  dma_buffer =
      dma_alloc_coherent(&pdev->dev, DMA_BUFFER_SIZE, &dma_handle, GFP_KERNEL);
  if (!dma_buffer) {
    dev_err(&pdev->dev, "Unable to allocate DMA buffer");
    ret = -ENOMEM;
    goto err_unmap_bar1;
  }

  if (request_irq(pdev->irq, pcie_interrupt_handler, IRQF_SHARED, "fpga_driver",
                  pdev)) {
    dev_err(&pdev->dev, "Unable to request IRQ");
    ret = -EBUSY;
    goto err_free_dma;
  }

  alloc_chrdev_region(&dev_num, 0, 1, DEVICE_NAME);
  cdev_init(&pcie_cdev, &pcie_fops);
  cdev_add(&pcie_cdev, dev_num, 1);

  pcie_class = class_create(DEVICE_NAME);
  device_create(pcie_class, NULL, dev_num, NULL, DEVICE_NAME);

  return 0;

err_free_dma:
  dma_free_coherent(&pdev->dev, DMA_BUFFER_SIZE, dma_buffer, dma_handle);
err_unmap_bar1:
  pci_iounmap(pdev, bar1_base);
err_unmap_bar0:
  pci_iounmap(pdev, bar0_base);
err_release_bar1:
  pci_release_region(pdev, 1);
err_release_bar0:
  pci_release_region(pdev, 0);
err_disable_device:
  pci_disable_device(pdev);
  return ret;
}

static void pcie_remove(struct pci_dev *pdev) {
  printk("Removing pcie driver");
  device_destroy(pcie_class, dev_num);
  class_destroy(pcie_class);
  cdev_del(&pcie_cdev);
  unregister_chrdev_region(dev_num, 1);

  free_irq(pdev->irq, pdev);
  dma_free_coherent(&pdev->dev, DMA_BUFFER_SIZE, dma_buffer, dma_handle);
  pci_iounmap(pdev, bar1_base);
  pci_iounmap(pdev, bar0_base);
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
