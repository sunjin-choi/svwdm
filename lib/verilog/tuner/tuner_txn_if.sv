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
  logic [DAC_WIDTH-1:0] tune_code;
  logic [ADC_WIDTH-1:0] meas_power;

  function automatic logic fire();
    return val & rdy;
  endfunction

  // Controller side
  modport ctrl(
      output val,
      output tune_code,
      input  rdy,
      input  meas_power,
      import fire
  );

  // Arbiter side
  modport arb(
      input  val,
      input  tune_code,
      output rdy,
      output meas_power,
      import fire
  );
endinterface

`default_nettype wire
