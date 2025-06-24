
`ifndef TUNER_PHY_PKG_SV
`define TUNER_PHY_PKG_SV

package tuner_phy_pkg;
  // FIXME: nested pkg support should be added to cmake build system
  /*import tuner_pkg::*;*/
  // FIXME tuner_pkg contents moved here
  // ----------------------------------------------------------------------
  // Parameters
  // ----------------------------------------------------------------------
  `define TUNER_CMD_WIDTH 5
  `define TUNER_STATE_WIDTH 5

  // ----------------------------------------------------------------------
  // Local Parameters
  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // Types
  // ----------------------------------------------------------------------
  typedef enum logic [`TUNER_CMD_WIDTH-1:0] {
    INIT,
    SEARCH,
    LOCK,
    UNLOCK
  } tuner_cmd_e;

  typedef enum logic [`TUNER_STATE_WIDTH-1:0] {
    IDLE,
    ACTIVE,
    DONE,
    ERROR
  } tuner_state_e;

  // ----------------------------------------------------------------------
  // Functions
  // ----------------------------------------------------------------------
  function automatic logic is_search_done(tuner_cmd_e cmd, tuner_state_e state);
    return (state == DONE) && (cmd == SEARCH);
  endfunction

  function automatic logic is_lock_done(tuner_cmd_e cmd, tuner_state_e state);
    return (state == DONE) && (cmd == LOCK);
  endfunction

  function automatic string tuner_cmd_to_string(tuner_cmd_e cmd);
    case (cmd)
      INIT: return "INIT";
      SEARCH: return "SEARCH";
      LOCK: return "LOCK";
      UNLOCK: return "UNLOCK";
      default: return "UNKNOWN";
    endcase
  endfunction
  // ----------------------------------------------------------------------

  // Actual tuner_phy_pkg package contents
  // ----------------------------------------------------------------------
  // Types
  // ----------------------------------------------------------------------
  typedef enum logic [2:0] {
    RED,
    BLUE,
    NONE
  } tuner_dir_e;

  typedef enum logic [`TUNER_STATE_WIDTH-1:0] {
    SEARCH_IDLE   = 8'h0,
    SEARCH_INIT   = 8'h1,
    SEARCH_ACTIVE = 8'h2,
    SEARCH_DONE   = 8'h3,
    SEARCH_ERROR  = 8'h4,
    SEARCH_INTR   = 8'h5
  } tuner_phy_search_state_e  /*verilator public*/;

  typedef enum logic [`TUNER_STATE_WIDTH-1:0] {
    LOCK_IDLE,
    LOCK_INIT,
    LOCK_DONE,
    LOCK_TRACK,
    LOCK_ERROR,
    LOCK_INTR
  } tuner_phy_lock_state_e  /*verilator public*/;

  typedef enum logic [2:0] {
    DETECT_IDLE   = 3'b000,
    DETECT_WAIT   = 3'b001,
    DETECT_ACTIVE = 3'b010,
    DETECT_DONE   = 3'b011
  } tuner_phy_detect_state_e;

  // Migrated to package since unsupported to be defined within interface
  // in SV-2005/Verilator-5.014
  typedef enum logic {
    PWR_READ,
    PWR_DETECT
  } tuner_phy_detect_if_state_e;
  // ----------------------------------------------------------------------

endpackage : tuner_phy_pkg

`endif
