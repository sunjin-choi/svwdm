# Define project-wide package ordering for Verilog sources. Packages should be
# listed with full paths, constructed using VERILOG_LIB_DIR.

set(VERILOG_PACKAGE_ORDER
    "${VERILOG_LIB_DIR}/photonics/wdm_pkg.sv"
    "${VERILOG_LIB_DIR}/tuner/tuner_pkg.sv"
    "${VERILOG_LIB_DIR}/tuner/tuner_phy_pkg.sv")
