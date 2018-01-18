
# schoolMIPS makefile
# Stanislav Zhelnio, 2018
#
# based on:
#      makefile for MIPSfpga

.PHONY: clean

# project name is the same as current folder name
PRJECT_NAME := $(shell basename $(CURDIR))

SOF := project/$(PRJECT_NAME).sof

clean:
	rm -rf project

project:
	mkdir project
	cp *.qpf project
	cp *.qsf project
	cp *.sdc project

gui:
	cd project && quartus $(PRJECT_NAME) &

build: project
	cd project && quartus_sh --flow compile $(PRJECT_NAME)

program:
	cd project && quartus_pgm -m JTAG -o "P;$(PRJECT_NAME).sof"
