package tuner_pkg;

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

endpackage : tuner_pkg
