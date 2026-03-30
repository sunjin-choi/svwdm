#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -ne 1 ]; then
  echo "usage: $0 <simulation-name>" >&2
  exit 64
fi

sim_name="$1"
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
build_dir="${BUILD_DIR:-${repo_root}/build}"

if [ ! -d "$build_dir" ]; then
  echo "build directory not found: $build_dir" >&2
  echo "configure the project first, for example:" >&2
  echo "  mkdir -p build && cd build && cmake .." >&2
  exit 1
fi

cd "$repo_root"
source "$repo_root/sourceme.sh"

if [ -z "${WAVEFORM_VIEWER:-}" ]; then
  echo "error: no waveform viewer found; install surfer or gtkwave, or set WAVEFORM_VIEWER explicitly" >&2
  exit 1
fi

cmake_args=(
  -S "$repo_root"
  -B "$build_dir"
  -DVERILOG_SRC_DIR="$VERILOG_SRC_DIR"
  -DVERILOG_LIB_DIR="$VERILOG_LIB_DIR"
  -DCPP_LIB_DIR="$CPP_LIB_DIR"
  -DVERILOG_SIM_DIR="$VERILOG_SIM_DIR"
  -DWAVEFORM_VIEWER:STRING="$WAVEFORM_VIEWER"
  -DWAVEFORM_FILE:STRING="$WAVEFORM_FILE"
)

if [ -n "${VERILATOR_ROOT:-}" ]; then
  cmake_args+=(-DVERILATOR_ROOT="$VERILATOR_ROOT")
fi

cmake "${cmake_args[@]}" >/dev/null

exec cmake --build "$build_dir" --target "wave-${sim_name}"
