#!/usr/bin/env bash

set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "usage: $0 <waveform-file> [surfer-args...]" >&2
  exit 64
fi

wave="$1"
shift

if [ "${wave#/}" = "$wave" ]; then
  wave="$PWD/$wave"
fi

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "${script_dir}/.." && pwd)"
sim_name="${SURFER_SIM_NAME:-$(basename "$(dirname "$wave")")}"

surfer_bin="${SURFER_BIN:-}"
if [ -z "$surfer_bin" ]; then
  surfer_bin="$(command -v surfer || true)"
fi

if [ -z "$surfer_bin" ]; then
  echo "surfer not found; install it or set SURFER_BIN" >&2
  exit 127
fi

state_file="${repo_root}/.surfer/${sim_name}.ron"
command_file="${repo_root}/.surfer/${sim_name}.sucl"
default_command_file="${repo_root}/.surfer/default.sucl"

launcher_args=()
if [ -f "$state_file" ]; then
  launcher_args+=(-s "$state_file")
elif [ -f "$command_file" ]; then
  launcher_args+=(-c "$command_file")
elif [ -f "$default_command_file" ]; then
  launcher_args+=(-c "$default_command_file")
fi

cd "$repo_root"
exec "$surfer_bin" "${launcher_args[@]}" "$wave" "$@"
