function(define_verilator_environment)
  set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
  set(CMAKE_CXX_STANDARD 17)
  set(CMAKE_CXX_STANDARD_REQUIRED ON)

  find_package(verilator HINTS $ENV{VERILATOR_ROOT} ${VERILATOR_ROOT})
  if(NOT verilator_FOUND)
    message(
      FATAL_ERROR
        "Verilator was not found. Either install it, or set the VERILATOR_ROOT environment variable"
    )
  endif()

  # Default VERILOG paths from env
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
  set(GTKWAVE_APP
      $ENV{GTKWAVE_APP}
      CACHE PATH "Path to gtkwave executable")
  set(WAVEFORM_FILE
      $ENV{WAVEFORM_FILE}
      CACHE PATH "Path to the waveform file")

  list(APPEND VERI_ARGS -Wall -Wno-fatal -sv --cc)

  message(STATUS "Verilog source directory: ${VERILOG_SRC_DIR}")
  message(STATUS "Verilog library directory: ${VERILOG_LIB_DIR}")
  message(STATUS "Verilog test directory: ${VERILOG_TEST_DIR}")
  message(STATUS "Verilog sim directory: ${VERILOG_SIM_DIR}")
  message(STATUS "Waveform file: ${WAVEFORM_FILE}")

  set(VERI_ARGS
      ${VERI_ARGS}
      PARENT_SCOPE)
  set(VERILOG_SRC_DIR
      ${VERILOG_SRC_DIR}
      PARENT_SCOPE)
  set(VERILOG_LIB_DIR
      ${VERILOG_LIB_DIR}
      PARENT_SCOPE)
  set(VERILOG_TEST_DIR
      ${VERILOG_TEST_DIR}
      PARENT_SCOPE)
  set(VERILOG_SIM_DIR
      ${VERILOG_SIM_DIR}
      PARENT_SCOPE)
  set(GTKWAVE_APP
      ${GTKWAVE_APP}
      PARENT_SCOPE)
  set(WAVEFORM_FILE
      ${WAVEFORM_FILE}
      PARENT_SCOPE)
endfunction()

function(add_gtkwave_target target_name)
  add_custom_target(
    ${target_name}
    COMMAND ${GTKWAVE_APP} "${CMAKE_CURRENT_BINARY_DIR}/${WAVEFORM_FILE}"
    DEPENDS "${CMAKE_CURRENT_BINARY_DIR}/${WAVEFORM_FILE}"
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    COMMENT "Running gtkwave")
endfunction()

function(add_verilated_testbench name top_module cpp_main)
  set(options)
  set(oneValueArgs PREFIX)
  set(multiValueArgs SOURCES VERILATOR_ARGS INCLUDE_DIRS EXTRA_SRC)
  cmake_parse_arguments(TESTBENCH "${options}" "${oneValueArgs}"
                        "${multiValueArgs}" ${ARGN})

  add_executable(${name} ${cpp_main} ${TESTBENCH_EXTRA_SRC})

  if(TESTBENCH_INCLUDE_DIRS)
    target_include_directories(${name} PRIVATE ${TESTBENCH_INCLUDE_DIRS})
  endif()

  verilate(
    ${name}
    SOURCES
    ${TESTBENCH_SOURCES}
    VERILATOR_ARGS
    ${TESTBENCH_VERILATOR_ARGS}
    TOP_MODULE
    ${top_module}
    PREFIX
    ${TESTBENCH_PREFIX}
    TRACE)
endfunction()
