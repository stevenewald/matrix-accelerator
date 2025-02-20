#include "dma_operations.h"
#include "fpga_driver.h"
#include "mmio_operations.h"

#include <linux/atomic.h>
#include <linux/cdev.h>
#include <linux/delay.h>
#include <linux/device.h>
#include <linux/dma-mapping.h>
#include <linux/module.h>
#include <linux/pci.h>
#include <linux/poll.h>
#include <linux/slab.h>
#include <linux/string.h>

// todo: move this to driver
#define PCIE_IOC_MAGIC 'k'
#define PCIE_SET_DMA _IOW(PCIE_IOC_MAGIC, 1, int)

static long pcie_ioctl(struct file *file, unsigned int cmd, unsigned long arg) {
  struct pcie_dev *pcie = file->private_data;
  int value;
  switch (cmd) {
  case PCIE_SET_DMA:
    if (copy_from_user(&value, (int __user *)arg, sizeof(int)))
      return -EFAULT;
    dev_info(&pcie->pdev->dev, "Setting dma to %d\n", value);
    pcie->use_dma = value;
    break;
  default:
    return -ENOTTY;
  }
  return 0;
}

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
  pcie->matrix_done = false;
  if (pcie->use_dma) {
    printk("Writing with DMA");
    return dma_write(pcie, buf, count, ppos);
  } else {
    printk("Writing with mmio");
    return mmio_write(pcie, buf, count, ppos);
  }
}

static ssize_t pcie_dma_read(struct file *file, char __user *buf, size_t count,
                             loff_t *ppos) {
  struct pcie_dev *pcie = file->private_data;
  if (pcie->use_dma) {
    printk("Reading with DMA");
    return dma_read(pcie, buf, count, ppos);
  } else {
    printk("Reading with mmio");
    return mmio_read(pcie, buf, count, ppos);
  }
}

static irqreturn_t pcie_interrupt_handler(int irq, void *dev_id) {
  struct pcie_dev *dev = (struct pcie_dev *)dev_id;
  if (irq == dev->dma_irq) {
    printk("DMA interrupt received on IRQ %d\n", irq);
    complete(&dev->dma_transfer_done);
  } else {
    printk("USR interrupt received on IRQ %d\n", irq);
    dev->matrix_done = true;
    wake_up_interruptible(&dev->matrix_wait_queue);
  }
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

static unsigned int pcie_poll(struct file *file, poll_table *wait) {
  struct pcie_dev *pcie = file->private_data;
  unsigned int mask = 0;

  poll_wait(file, &pcie->matrix_wait_queue, wait);
  printk("Ready!");

  if (pcie->matrix_done)
    mask |= POLLIN | POLLRDNORM;

  return mask;
}

static struct file_operations pcie_fops = {.owner = THIS_MODULE,
                                           .open = pcie_open,
                                           .release = pcie_release,
                                           .read = pcie_dma_read,
                                           .write = pcie_dma_write,
                                           .poll = pcie_poll,
                                           .unlocked_ioctl = pcie_ioctl,
                                           .llseek = pcie_llseek};

// DRIVER OPS

extern struct file_operations pcie_fops;

/* Helper: Enable PCI device and request BAR regions */
static int pcie_enable_and_request_regions(struct pci_dev *pdev,
                                           struct pcie_dev *dev) {
  int ret;

  ret = pci_enable_device(pdev);
  if (ret)
    return ret;

  ret = pci_request_region(pdev, 0, "MMIO Interface");
  if (ret) {
    pci_disable_device(pdev);
    return ret;
  }
  dev->mmio_bar_requested = true;

  ret = pci_request_region(pdev, 1, "DMA Interface");
  if (ret) {
    pci_release_region(pdev, 0);
    dev->mmio_bar_requested = false;
    pci_disable_device(pdev);
    return ret;
  }
  dev->dma_bar_requested = true;

  pci_set_master(pdev);
  return 0;
}

/* Helper: Map BAR0 and BAR1 */
static int pcie_map_bars(struct pci_dev *pdev, struct pcie_dev *dev) {
  dev->mmio_bar_len = pci_resource_len(pdev, 0);
  dev_info(&pdev->dev, "Detected BAR0 with size %pa\n", &dev->mmio_bar_len);
  dev->mmio_bar_base = pci_iomap(pdev, 0, dev->mmio_bar_len);
  if (!dev->mmio_bar_base)
    return -ENOMEM;

  dev->dma_bar_len = pci_resource_len(pdev, 1);
  dev_info(&pdev->dev, "Detected BAR1 with size %pa\n", &dev->dma_bar_len);
  dev->dma_bar_base = pci_iomap(pdev, 1, dev->dma_bar_len);
  if (!dev->dma_bar_base) {
    pci_iounmap(pdev, dev->mmio_bar_base);
    dev->mmio_bar_base = NULL;
    return -ENOMEM;
  }

  return 0;
}

/* Helper: Set up DMA mask and allocate a coherent DMA buffer */
static int pcie_setup_dma(struct pci_dev *pdev, struct pcie_dev *dev) {
  int ret;

  ret = dma_set_mask_and_coherent(&pdev->dev, DMA_BIT_MASK(32));
  if (ret) {
    dev_err(&pdev->dev, "No suitable DMA mask available");
    return ret;
  }

  dev->dma_buffer = dma_alloc_coherent(&pdev->dev, DMA_BUFFER_SIZE,
                                       &dev->dma_handle, GFP_KERNEL);
  if (!dev->dma_buffer)
    return -ENOMEM;

  return 0;
}

/* Helper: Allocate MSI IRQ vectors and request IRQs */
static int pcie_setup_irqs(struct pci_dev *pdev, struct pcie_dev *dev) {
  int ret;

  /* Request exactly 2 MSI vectors */
  if (pci_alloc_irq_vectors(pdev, 2, 2, PCI_IRQ_MSI) != 2) {
    dev_err(&pdev->dev, "Failed to allocate MSI vectors");
    return -EINVAL;
  }

  dev->usr_irq = pci_irq_vector(pdev, 0);
  dev->dma_irq = pci_irq_vector(pdev, 1);

  ret = request_irq(dev->usr_irq, pcie_interrupt_handler, 0, DEVICE_NAME, dev);
  if (ret) {
    dev_err(&pdev->dev, "Unable to request user IRQ");
    goto err_free_irq_vectors;
  }

  ret = request_irq(dev->dma_irq, pcie_interrupt_handler, 0, DEVICE_NAME, dev);
  if (ret) {
    dev_err(&pdev->dev, "Unable to request DMA IRQ");
    free_irq(dev->usr_irq, dev);
    goto err_free_irq_vectors;
  }

  return 0;

err_free_irq_vectors:
  pci_free_irq_vectors(pdev);
  return ret;
}

/* Helper: Set up character device and sysfs entries */
static int pcie_setup_chrdev(struct pcie_dev *dev) {
  int ret;

  ret = alloc_chrdev_region(&dev->devt, 0, 1, DEVICE_NAME);
  if (ret)
    return ret;

  cdev_init(&dev->cdev, &pcie_fops);
  ret = cdev_add(&dev->cdev, dev->devt, 1);
  if (ret) {
    unregister_chrdev_region(dev->devt, 1);
    return ret;
  }

  dev->class = class_create(DEVICE_NAME);
  if (IS_ERR(dev->class)) {
    ret = PTR_ERR(dev->class);
    cdev_del(&dev->cdev);
    unregister_chrdev_region(dev->devt, 1);
    return ret;
  }

  dev->device = device_create(dev->class, NULL, dev->devt, NULL, DEVICE_NAME);
  if (IS_ERR(dev->device)) {
    ret = PTR_ERR(dev->device);
    class_destroy(dev->class);
    cdev_del(&dev->cdev);
    unregister_chrdev_region(dev->devt, 1);
    return ret;
  }

  return 0;
}

/* Unified cleanup function for probe failure (or removal) */
static void pcie_cleanup(struct pci_dev *pdev) {
  struct pcie_dev *dev = pci_get_drvdata(pdev);
  printk("Removing pcie driver");
  if (!dev)
    return;

  if (dev->device)
    device_destroy(dev->class, dev->devt);
  if (dev->class)
    class_destroy(dev->class);
  cdev_del(&dev->cdev);
  unregister_chrdev_region(dev->devt, 1);

  if (dev->usr_irq)
    free_irq(dev->usr_irq, dev);
  if (dev->dma_irq)
    free_irq(dev->dma_irq, dev);
  pci_free_irq_vectors(pdev);

  if (dev->dma_buffer)
    dma_free_coherent(&pdev->dev, DMA_BUFFER_SIZE, dev->dma_buffer,
                      dev->dma_handle);

  if (dev->dma_bar_base)
    pci_iounmap(pdev, dev->dma_bar_base);
  if (dev->mmio_bar_base)
    pci_iounmap(pdev, dev->mmio_bar_base);

  if (dev->dma_bar_requested)
    pci_release_region(pdev, 1);
  if (dev->mmio_bar_requested)
    pci_release_region(pdev, 0);

  pci_disable_device(pdev);
}

/* Main probe function */
static int pcie_probe(struct pci_dev *pdev, const struct pci_device_id *id) {
  struct pcie_dev *dev;
  int ret;

  dev_info(&pdev->dev, "Initializing PCIe probe");

  dev = devm_kzalloc(&pdev->dev, sizeof(*dev), GFP_KERNEL);
  if (!dev)
    return -ENOMEM;

  init_completion(&dev->dma_transfer_done);
  mutex_init(&dev->dma_lock);
  init_waitqueue_head(&dev->matrix_wait_queue);

  dev->pdev = pdev;

  /* Initialize resource flags and pointers */
  dev->mmio_bar_requested = false;
  dev->dma_bar_requested = false;
  dev->mmio_bar_base = NULL;
  dev->dma_bar_base = NULL;
  dev->dma_buffer = NULL;
  dev->device = NULL;
  dev->class = NULL;
  dev->usr_irq = 0;
  dev->dma_irq = 0;

  ret = pcie_enable_and_request_regions(pdev, dev);
  if (ret)
    return ret;

  ret = pcie_map_bars(pdev, dev);
  if (ret)
    goto err_release_regions;

  ret = pcie_setup_dma(pdev, dev);
  if (ret)
    goto err_unmap_bars;

  ret = pcie_setup_irqs(pdev, dev);
  if (ret)
    goto err_free_dma;

  /* Configure DMA interrupts using BAR1 base */
  configure_dma_interrupts(dev->dma_bar_base);

  ret = pcie_setup_chrdev(dev);
  if (ret)
    goto err_free_irqs;

  pci_set_drvdata(pdev, dev);
  printk("FPGA Driver Loaded Successfully\n");
  return 0;

err_free_irqs:
  free_irq(dev->dma_irq, dev);
  free_irq(dev->usr_irq, dev);
  pci_free_irq_vectors(pdev);
err_free_dma:
  dma_free_coherent(&pdev->dev, DMA_BUFFER_SIZE, dev->dma_buffer,
                    dev->dma_handle);
err_unmap_bars:
  if (dev->dma_bar_base)
    pci_iounmap(pdev, dev->dma_bar_base);
  if (dev->mmio_bar_base)
    pci_iounmap(pdev, dev->mmio_bar_base);
err_release_regions:
  if (dev->dma_bar_requested)
    pci_release_region(pdev, 1);
  if (dev->mmio_bar_requested)
    pci_release_region(pdev, 0);
  pci_disable_device(pdev);
  return ret;
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
    .remove = pcie_cleanup,
};
module_pci_driver(pcie_driver);

MODULE_LICENSE("GPL");
