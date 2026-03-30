# SystemVerilog WDM Simulation Project

This project is a collection of SystemVerilog modules and C++ testbenches for simulating a Wavelength Division Multiplexing (WDM) system with microring resonators. The project uses Verilator to compile the SystemVerilog code into C++ for high-performance simulation.

## Project Structure

```
.
├── cmake/            # CMake helper scripts
├── docs/             # Sphinx documentation
├── lib/              # RTL libraries
│   ├── cpp/
│   └── verilog/
│       ├── circuits/
│       ├── photonics/
│       └── tuner/
├── sim/              # Simulation testbenches
└── src/              # Source files (not extensively used)
```

### RTL Libraries (`lib/verilog/`)

The `lib/verilog/` directory contains the core SystemVerilog modules for the WDM system.

*   **`circuits/`**: Basic analog and mixed-signal components like ADCs and DACs.
*   **`photonics/`**: Models for optical components, including:
    *   `laser.sv`: A multi-wavelength laser source.
    *   `microring.sv`: A single microring resonator.
    *   `microringrow.sv`: A row of microring resonators.
    *   `photodetector.sv`: A photodetector to convert optical power to electrical current.
*   **`tuner/`**: Control logic for tuning the microring resonators.
    *   `tuner_search_phy.sv`: Sweeps the tuning voltage to find resonance peaks.
    *   `tuner_lock_phy.sv`: Locks the microring's resonance to a specific wavelength.

Package compile order is defined in `cmake/VerilogPackages.cmake`.  Adjust this
file if additional packages are added or the order needs to change.

### Simulation (`sim/`)

The `sim/` directory contains the C++ testbenches for simulating the RTL modules. Each subdirectory is a self-contained simulation environment.

*   Each testbench has a `dut.sv` (Design Under Test) and a `tb.cpp` (testbench).
*   The `tb.cpp` file drives the simulation, provides inputs to the DUT, and checks the outputs.
*   The project uses CMake to build and run the simulations.

## Building and Running Simulations

To build the project, you will need to have CMake and Verilator installed.

1.  Configure the build directory:
    ```bash
    cmake -S . -B build
    ```

2.  Build all simulations:
    ```bash
    cmake --build build -j
    ```

3.  Run a specific simulation:
    ```bash
    cmake --build build --target run-<simulation_name> -j1
    ```
    For example, to run the `hello_world` simulation:
    ```bash
    cmake --build build --target run-hello_world -j1
    ```

4.  Run the tuner simulations with the helper script:
    ```bash
    ./scripts/run_tuner_sims.sh
    ```

If you add new RTL files, rerun the configure step so CMake regenerates the
Verilator source list.

## Requirements

Tested under:
- cmake v3.31.1
- verilator 5.014

## Formatting

This repo now includes formatter configuration for:

- SystemVerilog: `verible-verilog-format`
- C/C++: `clang-format`
- Python: `ruff`
- Shell: `shfmt`
- CMake: `cmake-format`

Install the formatter toolchain and git hooks with:

```bash
./scripts/bootstrap_formatters.sh
```

Format the whole repo with:

```bash
./scripts/format_repo.sh
```

Check formatting without modifying files with:

```bash
./scripts/format_repo.sh check
```

The same toolchain is reusable across sibling repos as long as they carry their
own repo-local config files.

### Vim Verible Autoformat

This repo also includes a reusable Vim snippet at `vim/verible_format.vim`.
Source it from your `~/.vimrc` to autoformat `*.sv`, `*.svh`, `*.v`, and
`*.vh` on save with `verible-verilog-format`. The snippet looks up the nearest
`.verible-verilog-format` file from the buffer directory upward, so the same
Vim config can work across multiple repos.

## Documentation

The project documentation is generated using Sphinx. To build the documentation, navigate to the `docs/` directory and run:

```bash
make html
```

The generated HTML documentation will be in the `docs/build/html/` directory.
