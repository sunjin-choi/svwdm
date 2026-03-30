#!/usr/bin/env bash

set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
plot_wave="${repo_root}/utils/plot_wave"
plots_dir="${repo_root}/plots"

mkdir -p "$plots_dir"

# Avoid matplotlib/fontconfig cache permission issues in restricted shells.
: "${XDG_CACHE_HOME:=${TMPDIR:-/tmp}/svwdm-cache}"
: "${MPLCONFIGDIR:=${XDG_CACHE_HOME}/matplotlib}"
export XDG_CACHE_HOME
export MPLCONFIGDIR
mkdir -p "$XDG_CACHE_HOME" "$MPLCONFIGDIR"

plot_if_exists() {
  local csv_file="$1"
  local output_file="$2"
  shift 2

  if [[ ! -f "$csv_file" ]]; then
    printf 'Skipping missing CSV: %s\n' "$csv_file" >&2
    return 0
  fi

  "$plot_wave" "$csv_file" --filepath "$output_file" "$@"
}

plot_if_exists \
  "${repo_root}/build/sim/tuner_search_lock/search_lock_waveform.csv" \
  "${plots_dir}/tuner_search_lock.png" \
  --state_col lock_state

plot_if_exists \
  "${repo_root}/build/sim/tuner_search_lock_row/search_lock_waveform_ring0.csv" \
  "${plots_dir}/tuner_search_lock_row_ring0.png" \
  --state_col lock_state

plot_if_exists \
  "${repo_root}/build/sim/tuner_search_lock_row/search_lock_waveform_ring1.csv" \
  "${plots_dir}/tuner_search_lock_row_ring1.png" \
  --state_col lock_state

plot_if_exists \
  "${repo_root}/build/sim/tuner_search_row/search_waveform_ring0.csv" \
  "${plots_dir}/tuner_search_row_ring0.png"

plot_if_exists \
  "${repo_root}/build/sim/tuner_search_row/search_waveform_ring1.csv" \
  "${plots_dir}/tuner_search_row_ring1.png"

plot_if_exists \
  "${repo_root}/build/sim/tuner_search/search_waveform.csv" \
  "${plots_dir}/tuner_search.png" \
  --time_col time \
  --state_col state
