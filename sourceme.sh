#!/usr/bin/bash

export VERILOG_SRC_DIR=$PWD/src
export VERILOG_LIB_DIR=$PWD/lib/verilog
export VERILOG_SIM_DIR=$PWD/sim

export WAVEFORM_VIEWER=$(which gtkwave)
export WAVEFORM_FILE="waveform.vcd"
