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

`define NUM_CHANNEL 8

module dut (
    // input signals
    input var real i_pwr,
    input var real i_wvl_ls,
    input var real i_wvl_ring[`NUM_CHANNEL],

    // output signals
    output real o_pwr_thru,
    output real o_pwr_drop[`NUM_CHANNEL]
);
  import wdm_pkg::*;

  `DECLARE_WAVES_TYPE(1)

  // ----------------------------------------------------------------------
  // Assigns
  // ----------------------------------------------------------------------
  WAVES_TYPE waves_in;
  WAVES_TYPE waves_thru;
  WAVES_TYPE waves_drop[`NUM_CHANNEL];
  real wvls[WAVES_WIDTH];
  real pwrs[WAVES_WIDTH];

  always_comb begin
    for (int i = 0; i < WAVES_WIDTH; i++) begin
      wvls[i] = i_wvl_ls;
      pwrs[i] = i_pwr;
    end
  end
  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // Instances
  // ----------------------------------------------------------------------
  laser #(
      .waves_t  (WAVES_TYPE),
      .NUM_WAVES(WAVES_WIDTH)
  ) laser (
      .i_real_pwr  (pwrs),
      .i_real_wvl  (wvls),
      .o_phot_waves(waves_in)
  );

  microringrow #(
      .waves_t(WAVES_TYPE),
      .FWHM(0.25),
      .TuningFullScale(10.0)
  ) microringrow (
      .i_phot_waves(waves_in),
      .i_real_wvl_ring(i_wvl_ring),
      .i_real_tuning_dist('{default: 0.0}),  // No tuning for now
      .i_real_temperature('{default: 0.0}),  // No temperature sensitivity for now
      .o_phot_waves_drop(waves_drop),
      .o_phot_waves_thru(waves_thru)
  );

  generate
    for (genvar i = 0; i < `NUM_CHANNEL; i++) begin : gen_pd_drop
      photodetector #(
          .waves_t(WAVES_TYPE)
      ) pd_drop (
          .i_phot_waves  (waves_drop[i]),
          .o_real_current(o_pwr_drop[i])
      );
    end
  endgenerate

  photodetector #(
      .waves_t(WAVES_TYPE)
  ) pd_thru (
      .i_phot_waves  (waves_thru),
      .o_real_current(o_pwr_thru)
  );
  // ----------------------------------------------------------------------

endmodule

`default_nettype wire

