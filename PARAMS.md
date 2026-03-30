# Tuner Parameterization Flow

This document describes the current tuner parameterization split:

- package constants define globally shared enum widths
- module parameters define structure, storage shape, and interface widths
- runtime config inputs carry experiment knobs from the C++ benches into RTL

The intent is parameterization-first RTL with lean test iteration:

- change widths or storage-shaping limits only when the RTL structure must change
- change search/lock behavior from C++ benches whenever possible
- avoid touching RTL for stimulus-only experiments

## Active Search Architecture

The active search path is `tuner_txn_if` based.

- `lib/verilog/tuner/tuner_phy.sv` instantiates `tuner_txn_if search_txn_if` and `tuner_ctrl_txn_adapter`
- `lib/verilog/tuner/tuner_search_phy.sv` consumes `tuner_txn_if.ctrl txn_if`
- `sim/tuner_search/dut.sv` and `sim/tuner_search_row/dut.sv` also instantiate `tuner_txn_if` plus `tuner_ctrl_txn_adapter` directly

Current flow:

1. `tuner_search_phy` emits tune transactions on `tuner_txn_if`
2. `tuner_ctrl_txn_adapter` converts those transactions into `tuner_ctrl_arb_if`
3. `tuner_ctrl_arb_phy` applies sync-to-detect timing and commits tune/power updates
4. `tuner_lock_phy` still talks directly on `tuner_ctrl_arb_if`

So today the architecture is mixed by design:

- search path: `tuner_txn_if`
- lock path: `tuner_ctrl_arb_if`
- synchronization and AFE control: `tuner_ctrl_arb_phy`

## Package-Level Constants

These are global compile-time constants, not per-instance overrides.

### `tuner_pkg`

Defined in `lib/verilog/tuner/tuner_pkg.sv`:

- `TUNER_CMD_WIDTH`
- `TUNER_STATE_WIDTH`

These size shared enums such as:

- `tuner_cmd_e`
- `tuner_state_e`
- `tuner_phy_search_state_e`
- `tuner_phy_lock_state_e`

These should stay compile-time unless the entire package/type system is redesigned for per-instance typing.

## Compile-Time Module Parameters

These are still compile-time because they size ports, counters, arrays, windows, or generated storage.

### Core sizing

Seen across `lib/verilog/tuner/tuner_phy.sv`, `lib/verilog/tuner/tuner_search_phy.sv`, `lib/verilog/tuner/tuner_lock_phy.sv`, and wrappers:

- `DAC_WIDTH`
- `ADC_WIDTH`
- `NUM_TARGET`

### Search structure

Defined in `lib/verilog/tuner/tuner_search_phy.sv`:

- `SEARCH_PEAK_WINDOW_HALFSIZE`
- `SEARCH_PEAK_THRES`

These drive:

- tracking window array sizes
- invalid-window sizing
- local counters and vote windows

### Lock structure

Defined in `lib/verilog/tuner/tuner_lock_phy.sv`:

- `LOCK_DELTA_WINDOW_SIZE`

This drives:

- delta history window sizes
- majority-vote threshold width
- associated counters

### Bounded runtime support

Defined in `lib/verilog/tuner/tuner_ctrl_arb_phy.sv`:

- `MAX_SYNC_CYCLE`

This is a compile-time bound used only to size `sync_cnt` and the runtime config input width. The active sync delay is runtime-configurable.

### Wrapper structure

Seen in the simulation wrappers:

- `NUM_WAVES`
- `NUM_CHANNEL`

These remain compile-time because they determine array shapes and wave bundle types.

## Runtime Config Inputs

These are the knobs that should be changed from C++ benches instead of editing RTL.

### Search runtime config

Threaded through `lib/verilog/tuner/tuner_phy.sv` or directly into search wrappers:

- `i_cfg_ring_tune_start`
- `i_cfg_ring_tune_end`
- `i_cfg_ring_tune_stride`
- `i_cfg_sync_cycle`

Meaning:

- `i_cfg_ring_tune_start`: first code to evaluate
- `i_cfg_ring_tune_end`: last code bound for the sweep
- `i_cfg_ring_tune_stride`: step exponent used by search, with effective step `1 << stride`
- `i_cfg_sync_cycle`: runtime sync delay between tune and commit, bounded by `MAX_SYNC_CYCLE`

### Lock runtime config

Threaded through `lib/verilog/tuner/tuner_phy.sv` into `lib/verilog/tuner/tuner_lock_phy.sv`:

- `i_cfg_lock_tune_stride`
- `i_cfg_lock_pwr_delta_thres`
- `i_cfg_ring_pwr_peak_ratio`
- `i_cfg_pwr_peak`
- `i_cfg_ring_tune_peak`

Meaning:

- `i_cfg_lock_tune_stride`: lock step exponent, with effective step `1 << stride`
- `i_cfg_lock_pwr_delta_thres`: runtime majority-vote threshold, clamped to `1..LOCK_DELTA_WINDOW_SIZE`
- `i_cfg_ring_pwr_peak_ratio`: ratio knob reserved for peak-relative lock targeting
- `i_cfg_pwr_peak`: peak power found by search or bench stimulus
- `i_cfg_ring_tune_peak`: peak tune code found by search or bench stimulus

## Current Runtime/Compile-Time Split

The current intended rule is:

- if a knob changes port widths, array sizes, window lengths, or counter widths, keep it compile-time
- if a knob only changes operating point, threshold, range, or stride, prefer a runtime input

Examples:

- `DAC_WIDTH`: compile-time
- `ADC_WIDTH`: compile-time
- `NUM_TARGET`: compile-time
- `SEARCH_PEAK_WINDOW_HALFSIZE`: compile-time
- `LOCK_DELTA_WINDOW_SIZE`: compile-time
- `i_cfg_ring_tune_stride`: runtime
- `i_cfg_lock_tune_stride`: runtime
- `i_cfg_sync_cycle`: runtime, bounded by `MAX_SYNC_CYCLE`
- `i_cfg_lock_pwr_delta_thres`: runtime, bounded by `LOCK_DELTA_WINDOW_SIZE`

## Where C++ Benches Own the Active Config

The runtime knobs are currently seeded from the benches:

- `sim/tuner_search/tb.cpp`
- `sim/tuner_search_row/tb.cpp`
- `sim/tuner_search_lock/tb.cpp`
- `sim/tuner_search_lock_row/tb.cpp`

This is the preferred experiment loop:

1. keep structural widths and storage bounds in RTL parameters
2. expose operating knobs as DUT inputs
3. set defaults and overrides from C++ benches
4. rerun the executable without re-verilating when only bench config changes

## What Is Still Not Runtime-Configurable

The following knobs still shape storage and are not yet runtime-configurable:

- `SEARCH_PEAK_WINDOW_HALFSIZE`
- `SEARCH_PEAK_THRES`
- `LOCK_DELTA_WINDOW_SIZE`
- `WAIT_CYCLE`
- `NUM_PWR_DETECT`

If these need runtime control later, the usual pattern is:

- keep a compile-time `MAX_*`
- size arrays and counters from `MAX_*`
- add a runtime `i_cfg_*`
- clamp the runtime value inside the RTL

## Practical Guidance

When adding a new tuner knob:

1. keep it compile-time if it changes widths, array shapes, or generate structure
2. make it a runtime input if it only changes behavior
3. thread it through the smallest surface possible
4. seed the old default from the C++ bench so regressions are easy to catch
5. rerun the affected sim binary before broad rebuilds
