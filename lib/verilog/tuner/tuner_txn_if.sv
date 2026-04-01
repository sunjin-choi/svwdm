//==============================================================================
// Tuner transaction interface
// Provides a combined request/response handshake for tuning operations.
//==============================================================================

`timescale 1ns/1ps
`default_nettype none

interface tuner_txn_if #(
    parameter int DAC_WIDTH = 8,
    parameter int ADC_WIDTH = 8
) (
    input logic i_clk,
    input logic i_rst
);
  logic val;
  logic rdy;
  logic session_req;
  logic session_grant;
  logic session_active;
  logic [DAC_WIDTH-1:0] tune_code;
  logic [ADC_WIDTH-1:0] meas_power;

  function automatic logic fire();
    return val & rdy;
  endfunction

  // Controller side
  modport ctrl(
      output val,
      output session_req,
      output session_active,
      output tune_code,
      input  session_grant,
      input  rdy,
      input  meas_power,
      import fire
  );

  // Arbiter side
  modport arb(
      input  val,
      input  session_req,
      input  session_active,
      input  tune_code,
      output session_grant,
      output rdy,
      output meas_power,
      import fire
  );
endinterface

`default_nettype wire
