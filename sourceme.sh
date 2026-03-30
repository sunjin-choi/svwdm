#!/usr/bin/bash

export VERILOG_SRC_DIR=$PWD/src
export VERILOG_LIB_DIR=$PWD/lib/verilog
export VERILOG_SIM_DIR=$PWD/sim

export CPP_LIB_DIR=$PWD/lib/cpp

if [ -z "${WAVEFORM_VIEWER:-}" ]; then
  if command -v surfer >/dev/null 2>&1; then
    export WAVEFORM_VIEWER=$PWD/scripts/open_wave_surfer.sh
  elif command -v gtkwave >/dev/null 2>&1; then
    export WAVEFORM_VIEWER=$(command -v gtkwave)
  fi
fi
export WAVEFORM_FILE="waveform.vcd"
