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

module microringrow #(
    parameter type waves_t = waves8_t,
    /*parameter real ResonanceWavelength = 1300.0,*/
    parameter int NUM_CHANNEL = 8,
    parameter real FWHM = 1,
    parameter real TuningFullScale = 10
) (
    // input signals
    input var waves_t i_phot_waves,
    input var real i_real_wvl_ring[NUM_CHANNEL],

    input var real i_real_tuning_dist[NUM_CHANNEL],
    input var real i_real_temperature[NUM_CHANNEL],

    // output signals
    output waves_t o_phot_waves_drop[NUM_CHANNEL],
    output waves_t o_phot_waves_thru
);
  import wdm_pkg::*;

  // ----------------------------------------------------------------------
  // Signals
  // ----------------------------------------------------------------------
  real ring_resonance_wavelength;
  real ring_fwhm;

  /* verilator lint_off UNOPTFLAT */
  waves_t waves_in_int[NUM_CHANNEL];
  waves_t waves_thru_int[NUM_CHANNEL];
  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // Assigns
  // ----------------------------------------------------------------------
  assign waves_in_int[0]   = i_phot_waves;
  assign o_phot_waves_thru = waves_thru_int[NUM_CHANNEL-1];

  // Instantiate microrings
  generate
    for (genvar i = 0; i < NUM_CHANNEL; i++) begin : g_ring_channels
      microring #(
          .waves_t(waves_t),
          .FWHM(FWHM),
          .TuningFullScale(TuningFullScale)
      ) microring (
          .i_phot_waves(waves_in_int[i]),
          .i_real_wvl_ring(i_real_wvl_ring[i]),
          .i_real_tuning_dist(i_real_tuning_dist[i]),
          .i_real_temperature(i_real_temperature[i]),
          .o_phot_waves_drop(o_phot_waves_drop[i]),
          .o_phot_waves_thru(waves_thru_int[i])
      );
    end
  endgenerate

  // Daisy-chain rings
  generate
    for (genvar j = 1; j < NUM_CHANNEL; j++) begin : g_ring_conn
      assign waves_in_int[j] = waves_thru_int[j-1];
    end
  endgenerate
  // ----------------------------------------------------------------------

endmodule

`default_nettype wire

