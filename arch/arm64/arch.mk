# arch stuff
TOOLCHAIN_PREFIX ?= aarch64-elf-
ARCH_LINKER_SCRIPT := arch/arm64/linker.ld

ARCH_COMPILEFLAGS := -march=armv8-a -DARCH_ARM64=1
ARCH_CFLAGS :=
ARCH_CPPFLAGS :=
ARCH_ASMFLAGS :=
ARCH_LDFLAGS := -z max-page-size=4096

