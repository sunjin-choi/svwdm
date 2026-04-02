get_filename_component(TB_NAME "${CMAKE_CURRENT_SOURCE_DIR}" NAME)

set(TUNER_SEARCH_LOCK_STRESS_DAC_WIDTH
    10
    CACHE STRING "DAC width for tuner_search_lock_stress")
set(TUNER_SEARCH_LOCK_STRESS_ADC_WIDTH
    ""
    CACHE STRING "ADC width for tuner_search_lock_stress (defaults to DAC width)")

if(TUNER_SEARCH_LOCK_STRESS_ADC_WIDTH STREQUAL "")
  set(_stress_adc_width "${TUNER_SEARCH_LOCK_STRESS_DAC_WIDTH}")
else()
  set(_stress_adc_width "${TUNER_SEARCH_LOCK_STRESS_ADC_WIDTH}")
endif()

set(VERI_SRC "${CMAKE_CURRENT_SOURCE_DIR}/dut.sv")
add_verilog_library_sources(VERI_SRC PHOTONICS TUNER CIRCUITS)

set(STRESS_VERI_ARGS
    ${VERI_ARGS}
    -GDAC_WIDTH=${TUNER_SEARCH_LOCK_STRESS_DAC_WIDTH}
    -GADC_WIDTH=${_stress_adc_width})

message(STATUS "${TB_NAME} sources: ${VERI_SRC}")

add_verilated_testbench(
  "${TB_NAME}"
  dut
  "${CMAKE_CURRENT_SOURCE_DIR}/tb.cpp"
  SOURCES
  ${VERI_SRC}
  VERILATOR_ARGS
  ${STRESS_VERI_ARGS}
  INCLUDE_DIRS
  "${CPP_LIB_DIR}"
  ADD_WAVE_TARGET
  CSV
  PREFIX
  Vdut)

target_compile_definitions(
  "${TB_NAME}" PRIVATE
  STRESS_DAC_WIDTH=${TUNER_SEARCH_LOCK_STRESS_DAC_WIDTH}
  STRESS_ADC_WIDTH=${_stress_adc_width})
