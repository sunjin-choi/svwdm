
`ifndef TUNER_PHY_PKG_SV
`define TUNER_PHY_PKG_SV

package tuner_phy_pkg;
  import tuner_pkg::*;
  // Actual tuner_phy_pkg package contents
  // ----------------------------------------------------------------------
  // Types
  // ----------------------------------------------------------------------
  typedef enum logic [2:0] {
    RED,
    BLUE,
    NONE
  } tuner_dir_e;

  // ----------------------------------------------------------------------
  // Controller States
  // ----------------------------------------------------------------------
  typedef enum logic [`TUNER_STATE_WIDTH-1:0] {
    SEARCH_IDLE   = 8'h0,
    SEARCH_INIT   = 8'h1,
    SEARCH_ACTIVE = 8'h2,
    SEARCH_DONE   = 8'h3,
    SEARCH_ERROR  = 8'h4,
    SEARCH_INTR   = 8'h5
  } tuner_phy_search_state_e  /*verilator public*/;

  typedef enum logic [`TUNER_STATE_WIDTH-1:0] {
    LOCK_IDLE  = 8'h0,
    LOCK_INIT  = 8'h1,
    LOCK_DONE  = 8'h2,
    LOCK_TRACK = 8'h3,
    LOCK_ERROR = 8'h4,
    LOCK_INTR  = 8'h5
  } tuner_phy_lock_state_e  /*verilator public*/;

  typedef enum logic [2:0] {
    DETECT_IDLE   = 3'b000,
    DETECT_WAIT   = 3'b001,
    DETECT_ACTIVE = 3'b010,
    DETECT_DONE   = 3'b011
  } tuner_phy_detect_state_e;

  typedef enum logic [1:0] {
    ARB_CTRL_INIT   = 2'b00,
    ARB_CTRL_TUNE   = 2'b01,  // Tuner update
    ARB_CTRL_SYNC   = 2'b10,  // Synchronize tuner code-to-pwr detect
    ARB_CTRL_COMMIT = 2'b11   // Compute next tuner code
  } tuner_phy_ctrl_arb_state_e;
  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // Error States
  // ----------------------------------------------------------------------
  typedef enum logic [`TUNER_STATE_WIDTH-1:0] {
    ERROR_DETECT_MULTI,
    ERROR_TUNE_MULTI,
    ERROR_TIMEOUT,
    ERROR_MAX_CODE,
    ERROR_MIN_CODE
  } tuner_phy_error_state_e  /*verilator public*/;
  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // Interface Types
  // ----------------------------------------------------------------------
  // Migrated to package since unsupported to be defined within interface
  // in SV-2005/Verilator-5.014
  typedef enum logic {
    PWR_READ,
    PWR_DETECT
  } tuner_phy_detect_if_state_e;

  // Migrated to package since unsupported to be defined within interface
  // in SV-2005/Verilator-5.014
  typedef enum logic [1:0] {
    CTRL_TUNE   = 2'b00,  // Tuner update
    CTRL_UPDATE = 2'b01   // Synchronize tuner code-to-pwr detect
  } tuner_phy_ctrl_arb_if_state_e;

  // Predefined Controller Channels
  typedef enum logic {
    CH_SEARCH = 1'b0,
    CH_LOCK   = 1'b1
  } tuner_ctrl_ch_e;
  // ----------------------------------------------------------------------

endpackage : tuner_phy_pkg

`endif
