# Define project-wide package ordering for Verilog sources
# Packages should be listed relative to VERILOG_LIB_DIR so paths remain portable.

set(VERILOG_PACKAGE_ORDER
    "${VERILOG_LIB_DIR}/photonics/wdm_pkg.sv"
    "${VERILOG_LIB_DIR}/tuner/tuner_pkg.sv"
    "${VERILOG_LIB_DIR}/tuner/tuner_phy_pkg.sv"
    CACHE STRING "Ordered list of Verilog package files")
