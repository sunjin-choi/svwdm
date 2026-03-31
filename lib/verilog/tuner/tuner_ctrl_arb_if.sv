//==============================================================================
// Author: Sunjin Choi
// Description: Tuner Interface Arbiter's Interface to interface with
// high-level logics like search/lock. Arbiter interfaces with Power Detector
// and Tuner.
// Signals:
// Note:
// Variable naming conventions:
//    signals => snake_case
//    Parameters (aliasing signal values) => SNAKE_CASE with all caps
//    Module Parameters => ALL_CAPS_SNAKE_CASE
//    Local Parameters => CamelCase
//==============================================================================

// verilog_format: off
`timescale 1ns/1ps
`default_nettype none
// verilog_format: on

interface tuner_ctrl_arb_if #(
    parameter int DAC_WIDTH = 8,
    parameter int ADC_WIDTH = 8
) (
    input logic i_clk,
    input logic i_rst
);
  import tuner_phy_pkg::*;

  // ----------------------------------------------------------------------
  // Signals
  // ----------------------------------------------------------------------
  // Assume two channels always (Search/Lock Ctrl PHYs)
  // Search ctrl channel: CH_SEARCH (1'b0)
  // Lock ctrl channel: CH_LOCK (1'b1)
  localparam int NumChannel = 4;

  logic                 ctrl_refresh     [NumChannel];
  logic                 ctrl_active      [NumChannel];

  // Control -> Arbiter: Ring tuning value (to be sent to AFE)
  logic [DAC_WIDTH-1:0] ring_tune        [NumChannel];
  // Controller
  logic                 tune_val         [NumChannel];
  // Arbiter/AFE
  logic                 tune_rdy;

  // Arbiter -> Control: Committed ring tune and detected power
  logic [DAC_WIDTH-1:0] ring_tune_commit;
  logic [ADC_WIDTH-1:0] pwr_commit;
  // Arbiter/AFE
  logic                 commit_val;
  // Controller
  logic                 commit_rdy       [NumChannel];

  // Internal signal
  tuner_ctrl_ch_e ch_curr, ch_prev;
  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // Logic
  // ----------------------------------------------------------------------
  function automatic logic get_ctrl_tune_ch_ack(tuner_ctrl_ch_e ch);
    return tune_rdy && tune_val[ch];
  endfunction

  function automatic logic get_ctrl_commit_ch_ack(tuner_ctrl_ch_e ch);
    return commit_rdy[ch] && commit_val;
  endfunction

  // Ownership is session-scoped. Keep the current owner until its session ends,
  // then acquire the next owner from a new session start request.
  function automatic tuner_ctrl_ch_e select_channel();
    logic search_session_start, lock_session_start;
    logic search_active, lock_active;

    search_session_start = ctrl_refresh[CH_SEARCH];
    lock_session_start = ctrl_refresh[CH_LOCK];
    search_active = ctrl_active[CH_SEARCH];
    lock_active = ctrl_active[CH_LOCK];

    if (ctrl_active[ch_prev]) return ch_prev;
    else if (search_session_start) return CH_SEARCH;
    else if (lock_session_start) return CH_LOCK;
    else if (search_active) return CH_SEARCH;
    else if (lock_active) return CH_LOCK;
    else
      return CH_NULL;
  endfunction

  // Update current channel
  always_ff @(posedge i_clk or posedge i_rst) begin
    if (i_rst) begin
      ch_prev <= CH_SEARCH;  // Default to search channel on reset
    end
    else begin
      if (select_channel() != CH_NULL) begin
        ch_prev <= select_channel();
      end
    end
  end

  assign ch_curr = (select_channel() == CH_NULL) ? ch_prev : select_channel();
  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // APIs
  // ----------------------------------------------------------------------
  function automatic logic get_ctrl_tune_ack(tuner_ctrl_ch_e ch);
    /*return get_ctrl_tune_ch_ack(ch) && (select_channel() == ch);*/
    return get_ctrl_tune_ch_ack(ch) && (ch_curr == ch);
  endfunction

  function automatic logic get_ctrl_commit_ack(tuner_ctrl_ch_e ch);
    /*return get_ctrl_commit_ch_ack(ch) && (select_channel() == ch);*/
    return get_ctrl_commit_ch_ack(ch) && (ch_curr == ch);
  endfunction

  // FIXME
  function automatic logic get_ctrl_refresh();
    return ctrl_refresh[ch_curr];
  endfunction

  function automatic logic get_pwr_detect_active();
    /*return ctrl_active[select_channel()];*/
    return ctrl_active[ch_curr];
  endfunction

  function automatic logic [DAC_WIDTH-1:0] get_ring_tune();
    /*return ring_tune[select_channel()];*/
    return ring_tune[ch_curr];
  endfunction

  // Polling functions
  function automatic logic any_ctrl_tune_val();
    return ctrl_active[ch_curr] && tune_val[ch_curr];
  endfunction

  function automatic logic any_ctrl_tune_ack();
    return get_ctrl_tune_ack(CH_SEARCH) || get_ctrl_tune_ack(CH_LOCK);
  endfunction

  function automatic logic any_ctrl_commit_ack();
    return get_ctrl_commit_ack(CH_SEARCH) || get_ctrl_commit_ack(CH_LOCK);
  endfunction
  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // Modports
  // ----------------------------------------------------------------------
  // Producer (control logic) modport
  modport producer(
      output ctrl_active,
      output ctrl_refresh,
      output ring_tune,
      output tune_val,
      input tune_rdy,
      input ring_tune_commit,
      input pwr_commit,
      input commit_val,
      output commit_rdy,
      import get_ctrl_tune_ack,
      import get_ctrl_commit_ack,
      import get_pwr_detect_active
  );

  // Consumer (arbiter logic) modport
  modport consumer(
      input ctrl_active,
      input ctrl_refresh,
      input ring_tune,
      input tune_val,
      output tune_rdy,
      output ring_tune_commit,
      output pwr_commit,
      output commit_val,
      input commit_rdy,
      import get_ctrl_tune_ack,
      import get_ctrl_commit_ack,
      import get_pwr_detect_active,
      import get_ctrl_refresh,
      import get_pwr_detect_active,
      import get_ring_tune,
      import any_ctrl_tune_val,
      import any_ctrl_tune_ack,
      import any_ctrl_commit_ack
  );
  // ----------------------------------------------------------------------

endinterface
