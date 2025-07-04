# Tuner RTL Naming and Coding Conventions

This document outlines the naming and coding conventions for the SystemVerilog RTLs in the tuner subsystem. Adhering to these conventions is crucial for maintaining code quality, readability, and consistency.

## 1. General Principles

- **Clarity over Brevity**: Names should be descriptive and unambiguous.
- **Consistency**: Apply the same conventions uniformly across all files.
- **Use of `snake_case`**: All identifiers (signals, modules, files) use `snake_case` unless specified otherwise.

## 2. File Naming

- **Convention**: `project_subsystem_type.sv`
- **Example**: `tuner_search_phy.sv`, `tuner_pwr_detect_if.sv`

## 3. Module, Interface, and Package Naming

- **Convention**: `lowercase_snake_case`
- **Example**: `tuner_ctrl_arb_phy`, `tuner_pwr_detect_if`

## 4. Port (Input/Output) Naming

- **Convention**: Use prefixes for direction and domain: `[direction]_[domain]_[signal_name]`
  - **Direction**: `i_` (input), `o_` (output).
  - **Domain (optional)**: `_dig_` (digital), `_afe_` (analog front-end), `_cfg_` (configuration), `_mon_` (monitor).
- **Example**: `i_dig_ring_pwr`, `o_dig_ring_tune`, `i_cfg_ring_tune_start`

## 5. Internal Signal Naming

- **Convention**: `lowercase_snake_case`.
- **Prefix Standardization**:
    - **Data Prefix**: Use a specific prefix for core data signals (e.g., `ring_tune` for the microring data value).
    - **Action Prefix**: Use a shorter, more generic prefix for related control/handshake signals (e.g., `tune_` for `val`/`rdy`/`ack`).
- **Example**: `state_next`, `tune_fire`, `ring_tune_commit`

## 6. State Machine Enum Naming

- **Convention**:
  - **Enum Type**: `TypeName_e` (e.g., `tuner_phy_search_state_e`).
  - **Enum Members**: `ALL_CAPS_SNAKE_CASE` (e.g., `SEARCH_IDLE`, `ARB_CTRL_TUNE`).

## 7. Parameter Naming

- **Convention**:
  - **Module Parameters** (e.g., `parameter int WIDTH`): `ALL_CAPS_SNAKE_CASE`.
  - **Local Parameters** (e.g., `localparam int SIZE`): `CamelCase`.
- **Example**: `parameter int DAC_WIDTH`, `localparam int NumChannel`

## 8. Interface Instance Naming

- **Convention**: For an interface named `project_subsystem_if`, the instance should be `subsystem_if`.
- **Example**: `tuner_pwr_detect_if` -> `pwr_detect_if`

## 9. Signal Name Abbreviations

To keep long names manageable without sacrificing clarity, use the following standard abbreviations:

| Full Word   | Abbreviation |
|-------------|--------------|
| power       | pwr          |
| control     | ctrl         |
| value       | val          |
| ready       | rdy          |
| acknowledge | ack          |
| window      | win          |
| incremented | inc          |
| decremented | dec          |
| previous    | prev         |
| number      | num          |
| detected    | det          |
| configuration| cfg         |
| monitor     | mon          |
| digital     | dig          |
| analog FE   | afe          |
