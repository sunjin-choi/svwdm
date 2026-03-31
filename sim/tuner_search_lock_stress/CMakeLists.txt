get_filename_component(TB_NAME "${CMAKE_CURRENT_SOURCE_DIR}" NAME)

set(VERI_SRC "${VERILOG_SIM_DIR}/tuner_search_lock/dut.sv")
add_verilog_library_sources(VERI_SRC PHOTONICS TUNER CIRCUITS)

message(STATUS "${TB_NAME} sources: ${VERI_SRC}")

add_verilated_testbench(
  "${TB_NAME}"
  dut
  "${CMAKE_CURRENT_SOURCE_DIR}/tb.cpp"
  SOURCES
  ${VERI_SRC}
  VERILATOR_ARGS
  ${VERI_ARGS}
  INCLUDE_DIRS
  "${CPP_LIB_DIR}"
  ADD_WAVE_TARGET
  CSV
  PREFIX
  Vdut)
