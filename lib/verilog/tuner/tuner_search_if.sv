//==============================================================================
// Author: Sunjin Choi
// Description: 
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

interface tuner_search_if #(
    parameter int DAC_WIDTH  = 8,
    parameter int ADC_WIDTH  = 8,
    parameter int NUM_TARGET = 8
) (
    input logic i_clk,
    input logic i_rst
);
  import tuner_phy_pkg::*;

  // ----------------------------------------------------------------------
  // Signals
  // ----------------------------------------------------------------------
  logic trig_val;
  logic trig_rdy;

  logic peaks_val;
  logic peaks_rdy;
  logic [ADC_WIDTH-1:0] pwr_peaks[NUM_TARGET];
  logic [DAC_WIDTH-1:0] ring_tune_peaks[NUM_TARGET];
  logic [$clog2(NUM_TARGET)-1:0] peaks_cnt;
  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // APIs
  // ----------------------------------------------------------------------
  function automatic logic get_trig_ack();
    return trig_val & trig_rdy;
  endfunction

  function automatic logic get_peaks_ack();
    return peaks_val & peaks_rdy;
  endfunction
  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // Modports
  // ----------------------------------------------------------------------
  modport producer(
      input trig_val,
      input peaks_rdy,
      output trig_rdy,
      output peaks_val,
      output pwr_peaks,
      output ring_tune_peaks,
      output peaks_cnt,
      import get_trig_ack,
      import get_peaks_ack
  );

  modport consumer(
      input trig_rdy,
      input peaks_val,
      output trig_val,
      output peaks_rdy,
      input pwr_peaks,
      input ring_tune_peaks,
      input peaks_cnt,
      import get_trig_ack,
      import get_peaks_ack
  );
  // ----------------------------------------------------------------------

endinterface

