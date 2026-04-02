#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
build_dir="${BUILD_DIR:-${repo_root}/build}"
plots_dir="${repo_root}/plots"

if [ ! -d "$build_dir" ]; then
  echo "build directory not found: $build_dir" >&2
  echo "configure the project first, for example:" >&2
  echo "  mkdir -p build && cd build && cmake .." >&2
  exit 1
fi

cmake --build "$build_dir" --target run-tuner_search_lock_stress
BUILD_DIR="$build_dir" "${script_dir}/plot_tuner_sims.sh"

open_if_exists() {
  local plot_file="$1"

  if [ ! -f "$plot_file" ]; then
    echo "plot not found: $plot_file" >&2
    return 0
  fi

  if command -v open >/dev/null 2>&1; then
    open "$plot_file"
  else
    echo "open not found; plot saved at $plot_file" >&2
  fi
}

open_if_exists "${plots_dir}/tuner_search_lock_stress.png"
