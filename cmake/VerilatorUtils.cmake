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
  if(NOT WAVEFORM_FILE)
    set(WAVEFORM_FILE
        waveform.vcd
        CACHE PATH "Path to the waveform file" FORCE)
  endif()

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
  set(WAVEFORM_VIEWER
      ${WAVEFORM_VIEWER}
      PARENT_SCOPE)
  set(WAVEFORM_FILE
      ${WAVEFORM_FILE}
      PARENT_SCOPE)
endfunction()

function(add_verilated_testbench name top_module cpp_main)
  set(options ADD_WAVE_TARGET CSV)
  set(oneValueArgs PREFIX)
  set(multiValueArgs SOURCES VERILATOR_ARGS INCLUDE_DIRS EXTRA_SRC)
  cmake_parse_arguments(TESTBENCH "${options}" "${oneValueArgs}"
                        "${multiValueArgs}" ${ARGN})

  target_include_directories(csv2 INTERFACE ${csv2_SOURCE_DIR}/include)
  target_compile_features(csv2 INTERFACE cxx_std_17)

  set(MODEL_TARGET "${name}_model")
  add_library(${MODEL_TARGET} STATIC)

  add_executable(${name} ${cpp_main} ${TESTBENCH_EXTRA_SRC})

  if(TESTBENCH_INCLUDE_DIRS)
    target_include_directories(${name} PRIVATE ${TESTBENCH_INCLUDE_DIRS})
  endif()

  if(TESTBENCH_PREFIX)
    set(_verilated_prefix "${TESTBENCH_PREFIX}")
  else()
    list(GET TESTBENCH_SOURCES 0 _verilated_top_src)
    get_filename_component(_verilated_top_name "${_verilated_top_src}" NAME_WE)
    string(MAKE_C_IDENTIFIER "V${_verilated_top_name}" _verilated_prefix)
  endif()

  set(_verilated_vdir
      "${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles/${MODEL_TARGET}.dir/${_verilated_prefix}.dir")
  set(_verilated_manifest "${_verilated_vdir}/${_verilated_prefix}_copy.cmake")
  set(_verilated_cmake "${_verilated_vdir}/${_verilated_prefix}.cmake")
  set(_verilated_args "${_verilated_vdir}/verilator_args.txt")

  # Regenerate the Verilator source manifest when HDL edits can change the
  # generated file set, otherwise the model target can retain stale objects.
  if(EXISTS "${_verilated_manifest}")
    set(_verilated_regenerate OFF)
    foreach(_verilated_src IN LISTS TESTBENCH_SOURCES)
      if(EXISTS "${_verilated_src}"
         AND "${_verilated_src}" IS_NEWER_THAN "${_verilated_manifest}")
        set(_verilated_regenerate ON)
        break()
      endif()
    endforeach()

    if(_verilated_regenerate)
      file(REMOVE "${_verilated_manifest}" "${_verilated_cmake}"
                  "${_verilated_args}")
    endif()
  endif()

  verilate(
    ${MODEL_TARGET}
    SOURCES
    ${TESTBENCH_SOURCES}
    VERILATOR_ARGS
    ${TESTBENCH_VERILATOR_ARGS}
    TOP_MODULE
    ${top_module}
    PREFIX
    ${TESTBENCH_PREFIX}
    TRACE_VCD
    TRACE_STRUCTS)

  target_link_libraries(${name} PRIVATE ${MODEL_TARGET} csv2)

  # Add run_<target> if it doesn't already exist
  set(RUN_TARGET "run-${name}")
  if(NOT TARGET ${RUN_TARGET})
    add_custom_target(
      ${RUN_TARGET}
      COMMAND ${CMAKE_COMMAND} -E env WAVEFORM_FILE=${WAVEFORM_FILE}
              $<TARGET_FILE:${name}>
      DEPENDS ${name}
      WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
      COMMENT "Running ${name}")
  else()
    message(
      WARNING "Target ${RUN_TARGET} already exists. Skipping auto run target.")
  endif()

  if(TESTBENCH_ADD_WAVE_TARGET)
    set(WAVE_TARGET "wave-${name}")
    if(NOT TARGET ${WAVE_TARGET})
      add_custom_target(
        ${WAVE_TARGET}
        COMMAND ${CMAKE_COMMAND} -E echo_append
                "Checking for waveform: ${WAVEFORM_FILE}... "
        COMMAND ${CMAKE_COMMAND} -E sleep 0.1
        # COMMAND
        # ${CMAKE_COMMAND} -E test -f
        # "${CMAKE_CURRENT_BINARY_DIR}/${WAVEFORM_FILE}" || ${CMAKE_COMMAND} -E
        # echo
        # "Waveform not found: ${CMAKE_CURRENT_BINARY_DIR}/${WAVEFORM_FILE}" &&
        # exit 1
        COMMAND ${WAVEFORM_VIEWER}
                "${CMAKE_CURRENT_BINARY_DIR}/${WAVEFORM_FILE}"
        WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
        COMMENT "Running waveform viewer for ${name}")
      add_dependencies(${WAVE_TARGET} ${RUN_TARGET})
    else()
      message(
        WARNING
          "Target ${WAVE_TARGET} already exists. Skipping auto wave target.")
    endif()
  endif()
endfunction()
