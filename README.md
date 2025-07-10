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

To build the project, you will need to have CMake and Verilator installed.  If
Verilator is not installed system-wide, set the `VERILATOR_ROOT` environment
variable so CMake can locate it.

1.  Create a build directory:
    ```bash
    mkdir build
    cd build
    ```

2.  Run CMake (setting `VERILATOR_ROOT` if needed):
    ```bash
    export VERILATOR_ROOT=/opt/verilator  # adjust path to your installation
    cmake ..
    ```

3.  Build the simulations:
    ```bash
    make
    ```

4.  Run a specific simulation:
    ```bash
    make run-<simulation_name>
    ```
    For example, to run the `hello_world` simulation:
    ```bash
    make run-hello_world
    ```

## Requirements

Tested under:
- cmake v3.31.1
- verilator 5.014

## Documentation

The project documentation is generated using Sphinx. To build the documentation, navigate to the `docs/` directory and run:

```bash
make html
```

The generated HTML documentation will be in the `docs/build/html/` directory.
