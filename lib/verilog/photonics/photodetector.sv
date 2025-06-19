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

module photodetector #(
    parameter type waves_t = waves8_t,
    parameter real Responsivity = 1.0
) (

    // input signals
    input var waves_t i_phot_waves,

    // output signals
    output real o_real_current

);
  import wdm_pkg::*;

  real real_pwr_tot;

  // ----------------------------------------------------------------------
  // Assigns
  // ----------------------------------------------------------------------
  // accumulate power
  always_comb begin : add_pwr
    real real_pwr_tmp = 0.0;
    foreach (i_phot_waves.wave_bundle[i]) begin
      real_pwr_tmp += i_phot_waves.wave_bundle[i].power;
    end
    real_pwr_tot = real_pwr_tmp;
  end

  // convert to current
  // ----------------------------------------------------------------------
  // Assigns
  // ----------------------------------------------------------------------
  assign o_real_current = real_pwr_tot * Responsivity;
  // ----------------------------------------------------------------------

endmodule

`default_nettype wire

