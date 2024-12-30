# Makefile

# defaults
SIM ?= nvc
TOPLEVEL_LANG ?= vhdl
GUI = 1
SCRIPT_FILE =

ifeq ($(SIM),ghdl)
	COMPILE_ARGS = --std=08
	EXTRA_ARGS = --std=08
	SIM_ARGS = --wave=lowpass_ema.ghw
endif

ifeq ($(SIM),nvc)
	SIM_ARGS = --wave=lowpass_ema.ghw
endif

SRC = ../src

# use VHDL_SOURCES for VHDL files
VHDL_SOURCES += $(SRC)/lowpass_ema.vhd \ 
				tb_lowpass_ema.vhd

nvc -a 