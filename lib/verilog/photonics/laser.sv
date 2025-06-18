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

import wdm_pkg::*;

module laser #(
    parameter type waves_t   = waves8_t,
    parameter int  NUM_WAVES = 8
) (

    // input signals
    /*input var real i_real_pwr[NUM_WAVES],*/
    input var real i_real_pwr[NUM_WAVES],
    input var real i_real_wvl[NUM_WAVES],

    // output signals
    output waves_t o_phot_waves

);

  // ----------------------------------------------------------------------
  // Assigns
  // ----------------------------------------------------------------------
  always_comb begin : create_waves
    foreach (o_phot_waves.wave_bundle[i]) begin
      o_phot_waves.wave_bundle[i].wavelength = i_real_wvl[i];
      o_phot_waves.wave_bundle[i].power      = i_real_pwr[i];
    end
  end
  // ----------------------------------------------------------------------

endmodule

`default_nettype wire

