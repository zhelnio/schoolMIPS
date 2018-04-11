
# toolchain prefix

# check if Codescape Toolchain (from MIPS website) is already installed
# otherway use mips toolchain from Ubuntu repository:
#  sudo apt install gcc-mipsel-linux-gnu
ifneq (, $(shell which mips-mti-elf-gcc))
	TOOLCHAIN = mips-mti-elf
else
	TOOLCHAIN = mipsel-linux-gnu
endif

# Path and program settings
CC = $(TOOLCHAIN)-gcc
LD = $(TOOLCHAIN)-gcc
OD = $(TOOLCHAIN)-objdump
OC = $(TOOLCHAIN)-objcopy
SZ = $(TOOLCHAIN)-size

#OS dependent
# sed
SED = sed
ifeq ($(OS), Windows_NT)
	SED  = ../../scripts/bin/sed
endif
