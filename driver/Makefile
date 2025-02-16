obj-m += fpga_driver.o
fpga_driver-objs := src/pcie.o src/dma_regs.o src/dma_operations.o src/dma_descriptor.o

KERNELDIR ?= /lib/modules/$(shell uname -r)/build
PWD := $(shell pwd)

EXTRA_CFLAGS += -I$(src)/include
EXTRA_CFLAGS += -O1

all:
	$(MAKE) -C $(KERNELDIR) M=$(PWD) modules

clean:
	$(MAKE) -C $(KERNELDIR) M=$(PWD) clean

