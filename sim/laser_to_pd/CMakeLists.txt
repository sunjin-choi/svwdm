set(VERI_SRC "${VERILOG_LIB_DIR}/photonics/wdm_pkg.sv"
             "${VERILOG_SIM_DIR}/laser_to_pd/dut.sv")

file(GLOB_RECURSE VERI_PHOT_SRC "${VERILOG_LIB_DIR}/photonics/*.sv")
list(APPEND VERI_SRC ${VERI_PHOT_SRC})

# Add testbench using helper
add_verilated_testbench(
  laser_to_pd
  dut
  "${CMAKE_CURRENT_SOURCE_DIR}/tb.cpp"
  SOURCES
  ${VERI_SRC}
  VERILATOR_ARGS
  ${VERI_ARGS}
  # INCLUDE_DIRS "${VERILOG_SIM_DIR}/phase_tracking/sw/include"
  EXTRA_SRC
  ${SIM_SOURCES}
  ADD_WAVE_TARGET
  PREFIX
  Vsim)
