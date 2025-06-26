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
//    Parameters (not aliasing signal values) => CamelCase
//==============================================================================

// verilog_format: off
`timescale 1ns/1ps
`default_nettype none
// verilog_format: on

interface tuner_ctrl_arb_if #(
    parameter int DAC_WIDTH = 8,
    parameter int ADC_WIDTH = 8
) (
    input logic clk,
    input logic rst
);


  logic                 ctrl_refresh;

  logic                 ctrl_active;

  // Control -> Arbiter: Ring tuning value (to be sent to AFE)
  logic [DAC_WIDTH-1:0] ring_tune;
  logic                 ring_tune_val;
  logic                 ring_tune_rdy;

  // Arbiter -> Control: Committed ring tune and detected power
  logic [DAC_WIDTH-1:0] ring_tune_commit;
  logic [ADC_WIDTH-1:0] pwr_commit;
  logic                 commit_val;
  logic                 commit_rdy;

  // APIs
  function automatic get_ctrl_ring_tune_ack();
    return ring_tune_rdy && ring_tune_val;
  endfunction

  function automatic get_ctrl_commit_ack();
    return commit_rdy && commit_val;
  endfunction

  function automatic get_pwr_detect_active();
    // Assume power detector should be always active when ctrl_active is high
    return ctrl_active;
  endfunction

  // Producer (control logic) modport
  modport producer(
      output ctrl_active,
      output ctrl_refresh,
      output ring_tune,
      output ring_tune_val,
      input ring_tune_rdy,
      input ring_tune_commit,
      input pwr_commit,
      input commit_val,
      output commit_rdy,
      import get_ctrl_ring_tune_ack,
      import get_ctrl_commit_ack,
      import get_pwr_detect_active
  );

  // Consumer (arbiter logic) modport
  modport consumer(
      input ctrl_active,
      input ctrl_refresh,
      input ring_tune,
      input ring_tune_val,
      output ring_tune_rdy,
      output ring_tune_commit,
      output pwr_commit,
      output commit_val,
      input commit_rdy,
      import get_ctrl_ring_tune_ack,
      import get_ctrl_commit_ack,
      import get_pwr_detect_active
  );

endinterface

