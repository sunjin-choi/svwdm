# set(VERI_SRC "${VERILOG_LIB_DIR}/photonics/wdm_pkg.sv"
# "${VERILOG_SIM_DIR}/laser_to_pd/dut.sv")
#
# file(GLOB_RECURSE VERI_PHOT_SRC "${VERILOG_LIB_DIR}/photonics/*.sv")
# list(APPEND VERI_SRC ${VERI_PHOT_SRC})

get_filename_component(TB_NAME "${CMAKE_CURRENT_SOURCE_DIR}" NAME)

set(VERI_SRC "${VERILOG_SIM_DIR}/${TB_NAME}/dut.sv")
set(SIM_SOURCES "${VERILOG_SIM_DIR}/${TB_NAME}/tb.cpp")
add_verilog_library_sources(VERI_SRC PHOTONICS TUNER CIRCUITS)

message(STATUS "${TB_NAME} sources: ${VERI_SRC}")

# Add testbench using helper
add_verilated_testbench(
  "${TB_NAME}"
  dut
  "${CMAKE_CURRENT_SOURCE_DIR}/tb.cpp"
  SOURCES
  ${VERI_SRC}
  VERILATOR_ARGS
  ${VERI_ARGS}
  INCLUDE_DIRS
  "${VERILOG_SRC_DIR}/utils/cpp"
  EXTRA_SRC
  ${SIM_SOURCES}
  ADD_WAVE_TARGET
  CSV
  PREFIX
  Vsim)
