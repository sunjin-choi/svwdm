//==============================================================================
// Author: Sunjin Choi
// Description: 
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

// TODO: peak code and pwr should be grouped as peaks struct?
interface tuner_lock_if #(
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

  logic track_rdy;
  logic track_val;

  // Monitor signals
  /*logic mon_peak_commit;
   *logic mon_search_active_update;
   *logic [ADC_WIDTH-1:0] mon_ring_pwr;
   *logic [DAC_WIDTH-1:0] mon_ring_tune;*/
  /*logic [ADC_WIDTH-1:0] mon_pwr_peak;
   *logic [DAC_WIDTH-1:0] mon_ring_tune_peak;*/
  tuner_phy_lock_state_e mon_state;
  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // APIs
  // ----------------------------------------------------------------------
  function automatic logic get_trig_ack();
    return trig_val & trig_rdy;
  endfunction

  function automatic logic get_track_ack();
    return track_val & track_rdy;
  endfunction
  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // Modports
  // ----------------------------------------------------------------------
  // Lock PHY Controller
  modport producer(
      input trig_val,
      output trig_rdy,
      input track_val,
      output track_rdy,

      // Monitors
      /*output mon_pwr_peak,
       *output mon_ring_tune_peak,*/
      output mon_state,

      // APIs
      import get_trig_ack,
      import get_track_ack
  );

  // Lock PHY
  modport consumer(
      input trig_rdy,
      output trig_val,
      input track_rdy,
      output track_val,

      // APIs
      import get_trig_ack,
      import get_track_ack
  );

  modport monitor(input mon_state);
  // ----------------------------------------------------------------------

endinterface

