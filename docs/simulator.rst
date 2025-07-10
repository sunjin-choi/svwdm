Simulator Documentation
=======================

This section provides an overview of the simulation structure of the project.

.. contents::
   :local:

CMake Build System
------------------

The project uses CMake to build and run the simulations. The `cmake/` directory contains helper scripts for the build system.

*   **ProjectUtils.cmake**: Provides utility functions for the project, such as finding and sorting Verilog source files.
*   **VerilatorUtils.cmake**: Provides functions for setting up and running Verilator.

Before configuring the build, ensure Verilator is installed and visible to CMake. If
Verilator resides in a custom location, set the ``VERILATOR_ROOT`` environment
variable:

.. code-block:: bash

   export VERILATOR_ROOT=/opt/verilator

Run CMake from your build directory:

.. code-block:: bash

   cmake ..

Simulation Testbenches
----------------------

The `sim/` directory contains the C++ testbenches for simulating the RTL modules. Each subdirectory is a self-contained simulation environment.

*   Each testbench has a `dut.sv` (Design Under Test) and a `tb.cpp` (testbench).
*   The `tb.cpp` file drives the simulation, provides inputs to the DUT, and checks the outputs.

Workflow
--------

1.  The top-level `CMakeLists.txt` includes the `cmake/` and `sim/` directories.
2.  The `sim/CMakeLists.txt` file recursively adds all the testbench subdirectories.
3.  Each testbench's `CMakeLists.txt` file uses the helper functions in the `cmake/` directory to:
    *   Gather the necessary SystemVerilog source files.
    *   Use Verilator to compile the SystemVerilog code into a C++ model.
    *   Compile the C++ testbench (`tb.cpp`).
    *   Link the Verilated model and the C++ testbench to create a simulation executable.
