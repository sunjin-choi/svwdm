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

module dut (
    // input signals
    input var real i_pwr,
    input var real i_wvl_center,
    input var real i_wvl_spacing,

    // output signals
    output real o_pd
);
  import wdm_pkg::*;

  `DECLARE_WAVES_TYPE(8)

  // ----------------------------------------------------------------------
  // Assigns
  // ----------------------------------------------------------------------
  WAVES_TYPE waves;
  real wvls[WAVES_WIDTH];
  real pwrs[WAVES_WIDTH];

  /*assign pwrs = {'i_pwr};*/

  initial begin
    for (int i = 0; i < WAVES_WIDTH; i++) begin
      wvls[i] = i_wvl_center + i * i_wvl_spacing;
      pwrs[i] = i_pwr;
    end
  end

  assign o_pd = 0.0;

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
      .o_phot_waves(waves)
  );

  photodetector #(
      .waves_t(WAVES_TYPE)
  ) photodetector (
      .i_phot_waves  (waves),
      .o_real_current(o_pd)
  );
  // ----------------------------------------------------------------------

endmodule

`default_nettype wire

