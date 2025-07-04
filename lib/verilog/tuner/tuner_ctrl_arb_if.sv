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

  // Assume two channels always (Search/Lock Ctrl PHYs)
  // Search ctrl channel: CH_SEARCH (1'b0)
  // Lock ctrl channel: CH_LOCK (1'b1)
  localparam int NumChannel = 2;

  logic                 ctrl_refresh;
  logic                 ctrl_active;

  // Control -> Arbiter: Ring tuning value (to be sent to AFE)
  logic [DAC_WIDTH-1:0] ring_tune;
  // Controller
  logic                 tune_val    [NumChannel];
  // Arbiter/AFE
  logic                 tune_rdy;

  // Arbiter -> Control: Committed ring tune and detected power
  logic [DAC_WIDTH-1:0] ring_tune_commit;
  logic [ADC_WIDTH-1:0] pwr_commit;
  // Arbiter/AFE
  logic                 commit_val;
  // Controller
  logic                 commit_rdy       [NumChannel];

  // APIs
  /*  function automatic logic get_ctrl_ring_tune_ack();
 *    return ring_tune_rdy && ring_tune_val;
 *  endfunction
 *
 *  function automatic logic get_ctrl_commit_ack();
 *    return commit_rdy && commit_val;
 *  endfunction*/

  function automatic logic get_pwr_detect_active();
    // Assume power detector should be always active when ctrl_active is high
    return ctrl_active;
  endfunction

  // Priority level for multi-channel design
  // 1. Search takes priority over Lock
  // 2. If one claims ring_tune, it should also claim commit

  function automatic logic get_ctrl_tune_ch_ack(tuner_ctrl_ch_e ch);
    return tune_rdy && tune_val[ch];
  endfunction

  function automatic logic get_ctrl_commit_ch_ack(tuner_ctrl_ch_e ch);
    return commit_rdy[ch] && commit_val;
  endfunction

  function automatic tuner_ctrl_ch_e select_channel();
    logic search_tune_ack, search_commit_ack;
    logic lock_tune_ack, lock_commit_ack;

    search_tune_ack = get_ctrl_tune_ch_ack(CH_SEARCH);
    search_commit_ack = get_ctrl_commit_ch_ack(CH_SEARCH);
    lock_tune_ack = get_ctrl_tune_ch_ack(CH_LOCK);
    lock_commit_ack = get_ctrl_commit_ch_ack(CH_LOCK);

    if (search_tune_ack) return CH_SEARCH;
    else if (lock_tune_ack) return CH_LOCK;
    else if (search_commit_ack) return CH_SEARCH;
    else if (lock_commit_ack) return CH_LOCK;
    else return CH_SEARCH;  // Default to search channel if no ack
  endfunction

  function automatic logic get_ctrl_tune_ack(tuner_ctrl_ch_e ch);
    return get_ctrl_tune_ch_ack(ch) && (select_channel() == ch);
  endfunction

  function automatic logic get_ctrl_commit_ack(tuner_ctrl_ch_e ch);
    return get_ctrl_commit_ch_ack(ch) && (select_channel() == ch);
  endfunction

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
      import get_pwr_detect_active
  );
  // ----------------------------------------------------------------------

endinterface

