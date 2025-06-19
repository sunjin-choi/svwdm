set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

cmake_minimum_required(VERSION 3.12)
cmake_policy(SET CMP0074 NEW)

project(svwdm)

# Load custom functions

# look for cmake directory
if(NOT CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
  message(FATAL_ERROR "This project must be built in the source directory.")
endif()

list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake")
include(VerilatorUtils)
include(ProjectUtils)

# Add external libraries TODO: refactor
include(FetchContent)
FetchContent_Declare(
  tabulate
  GIT_REPOSITORY https://github.com/p-ranav/tabulate.git
  GIT_TAG master)
FetchContent_MakeAvailable(tabulate)
FetchContent_Declare(
  csv2
  GIT_REPOSITORY https://github.com/p-ranav/csv2
  GIT_TAG master)
FetchContent_MakeAvailable(csv2)

set(VERILOG_SRC_DIR
    $ENV{VERILOG_SRC_DIR}
    CACHE PATH "Path to the verilog source directory")
set(VERILOG_LIB_DIR
    $ENV{VERILOG_LIB_DIR}
    CACHE PATH "Path to the verilog library directory")
set(VERILOG_TEST_DIR
    $ENV{VERILOG_TEST_DIR}
    CACHE PATH "Path to the verilog test directory")
set(VERILOG_SIM_DIR
    $ENV{VERILOG_SIM_DIR}
    CACHE PATH "Path to the verilog sim directory")
set(WAVEFORM_VIEWER
    $ENV{WAVEFORM_VIEWER}
    CACHE STRING "Path to the waveform viewer executable")

message(STATUS "Verilog source directory: ${VERILOG_SRC_DIR}")
message(STATUS "Verilog library directory: ${VERILOG_LIB_DIR}")
message(STATUS "Verilog test directory: ${VERILOG_TEST_DIR}")
message(STATUS "Verilog sim directory: ${VERILOG_SIM_DIR}")

# Setup environment
define_verilator_environment()

# Subdirectories for modular build

# add_subdirectory(tests)
add_subdirectory(sim)
