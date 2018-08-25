include lk/make/macros.mk
NOECHO ?= @
# try to have the compiler output colorized error messages if available
export GCC_COLORS ?= 1

all: _all

APPS :=

APP_RULES := $(shell find apps -name app.mk)
$(warning APP_RULES = $(APP_RULES))

BUILDDIR := build
CCACHE ?=
ARCH ?= arm

ifeq ($(ARCH), arm)
    TARGET := arm-eabi
    export CORTEX_CORE := a15
    QEMU_EXE := qemu-system-arm
else
ifeq ($(ARCH), arm64)
    TARGET := aarch64-elf
    export CORTEX_CORE := a53
    QEMU_EXE := qemu-system-aarch64
else
	$(error $(ARCH) is not supported)
endif
endif

# some newlib stuff
NEWLIB_INSTALL_DIR := install-newlib-$(ARCH)
NEWLIB_INC_DIR := $(NEWLIB_INSTALL_DIR)/$(TARGET)/include
LIBC := $(NEWLIB_INSTALL_DIR)/$(TARGET)/lib/libc.a
LIBM := $(NEWLIB_INSTALL_DIR)/$(TARGET)/lib/libm.a

NEWLIB_BUILD_DIR := build-newlib-$(ARCH)

# compiler flags
GLOBAL_COMPILEFLAGS := -g -fno-builtin -finline -O2
GLOBAL_COMPILEFLAGS += -W -Wall -Wno-multichar -Wno-unused-parameter -Wno-unused-function -Wno-unused-label -Werror=return-type
GLOBAL_CFLAGS := --std=gnu99 -Werror-implicit-function-declaration -Wstrict-prototypes -Wwrite-strings
GLOBAL_CPPFLAGS := -fno-exceptions -fno-rtti -fno-threadsafe-statics
GLOBAL_ASMFLAGS := -DASSEMBLY
GLOBAL_LDFLAGS :=
GLOBAL_INCLUDES := -I$(NEWLIB_INC_DIR) -Isys/lib/lkuser/include
GLOBAL_LIBS := $(LIBC) $(LIBM)

GLOBAL_COMPILEFLAGS += -ffunction-sections -fdata-sections
GLOBAL_LDFLAGS += --gc-sections

include arch/$(ARCH)/arch.mk

ARCH_CC ?= $(CCACHE) $(TOOLCHAIN_PREFIX)gcc
ARCH_LD ?= $(TOOLCHAIN_PREFIX)ld
ARCH_OBJDUMP ?= $(TOOLCHAIN_PREFIX)objdump
ARCH_OBJCOPY ?= $(TOOLCHAIN_PREFIX)objcopy
ARCH_CPPFILT ?= $(TOOLCHAIN_PREFIX)c++filt
ARCH_SIZE ?= $(TOOLCHAIN_PREFIX)size
ARCH_NM ?= $(TOOLCHAIN_PREFIX)nm
ARCH_STRIP ?= $(TOOLCHAIN_PREFIX)strip

LIBGCC := $(shell $(ARCH_CC) $(GLOBAL_COMPILEFLAGS) $(ARCH_COMPILEFLAGS) $(THUMBCFLAGS) -print-libgcc-file-name)
$(info LIBGCC = $(LIBGCC))

include $(APP_RULES)
$(warning APPS = $(APPS))

_all: lk $(APPS)

lk:
	$(MAKE) -f makefile.lk

clean:
	$(MAKE) -f makefile.lk clean
	rm -rf -- "."/$(BUILDDIR)

spotless: clean clean-newlib
	$(MAKE) -f makefile.lk spotless

configure-newlib $(NEWLIB_BUILD_DIR)/Makefile:
	mkdir -p $(NEWLIB_BUILD_DIR)
	cd $(NEWLIB_BUILD_DIR) && ../newlib/configure --target $(TARGET) --disable-newlib-supplied-syscalls --prefix=`pwd`/../$(NEWLIB_INSTALL_DIR)

$(NEWLIB_BUILD_DIR) $(LIBC) $(LIBM): $(NEWLIB_BUILD_DIR)/Makefile
	mkdir -p $(NEWLIB_INSTALL_DIR)
	$(MAKE) -C $(NEWLIB_BUILD_DIR)
	$(MAKE) -C $(NEWLIB_BUILD_DIR) install MAKEFLAGS=

clean-newlib:
	rm -rf $(NEWLIB_BUILD_DIR) $(NEWLIB_INSTALL_DIR)

$(BUILDDIR)/apps.fs: $(APPS)
	@$(MKDIR)
	@echo generating $@ from $(APPS)
	$(NOECHO)dd if=/dev/zero of=$@ bs=1048576 count=16
	$(NOECHO)cat $(APPS) | dd of=$@ conv=notrunc

test: lk $(APPS) $(BUILDDIR)/apps.fs
	$(QEMU_EXE) -cpu cortex-$(CORTEX_CORE) -m 512 -machine virt -kernel build-qemu-usertest/lk.elf -nographic -drive if=none,file=$(BUILDDIR)/apps.fs,id=blk,format=raw -device virtio-blk-device,drive=blk

.PHONY: all _all lk clean spotless $(NEWLIB_BUILD_DIR) configure-newlib clean-newlib

# vim: set noexpandtab ts=4 sw=4:
