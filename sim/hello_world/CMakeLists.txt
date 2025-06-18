set(VERI_SRC "${VERILOG_SRC_DIR}/hello_world/hello_world.sv")

# Add testbench using helper
add_verilated_testbench(
  hello_world
  hello_world
  "${CMAKE_CURRENT_SOURCE_DIR}/hello_world.cpp"
  SOURCES
  ${VERI_SRC}
  VERILATOR_ARGS
  ${VERI_ARGS}
  # INCLUDE_DIRS "${VERILOG_SIM_DIR}/phase_tracking/sw/include"
  EXTRA_SRC
  ${SIM_SOURCES}
  PREFIX
  Vsim)
