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

`define ADC_WIDTH 8

module dut (
    input var logic i_clk,
    input var logic i_rst,

    // input signals
    input var real i_pwr,
    input var real i_wvl_ls,
    input var real i_wvl_ring,

    // output signals
    output real o_pwr_thru,
    output real o_pwr_drop,

    output logic [`ADC_WIDTH-1:0] o_adc_thru,
    output logic [`ADC_WIDTH-1:0] o_adc_drop,

    output logic o_dig_pwr_thru_detect_fire,
    output logic [`ADC_WIDTH-1:0] o_dig_pwr_thru_detect
);
  import wdm_pkg::*;

  `DECLARE_WAVES_TYPE(1)

  // ----------------------------------------------------------------------
  // Assigns
  // ----------------------------------------------------------------------
  WAVES_TYPE waves_in;
  WAVES_TYPE waves_thru;
  WAVES_TYPE waves_drop;
  real wvls[WAVES_WIDTH];
  real pwrs[WAVES_WIDTH];

  /*assign pwrs = {'i_pwr};*/

  always_comb begin
    for (int i = 0; i < WAVES_WIDTH; i++) begin
      wvls[i] = i_wvl_ls;
      pwrs[i] = i_pwr;
    end
  end

  tuner_pwr_detect_if #(
      .ADC_WIDTH(`ADC_WIDTH)
  ) pwr_detect_if (
      .i_clk(i_clk),
      .i_rst(i_rst)
  );

  // Broke rdy/val interface for now for simplicity
  /*assign pwr_detect_if.read_val = 1'b1;
   *assign pwr_detect_if.detect_rdy = 1'b1;*/
  /*assign o_dig_pwr_thru_detect_val = pwr_detect_if.detect_val;*/
  assign o_dig_pwr_thru_detect_fire = pwr_detect_if.get_detect_ack();
  assign o_dig_pwr_thru_detect = pwr_detect_if.detect_data;

  assign pwr_detect_if.pwr_detect_active = 1'b1;
  assign pwr_detect_if.pwr_detect_refresh = 1'b0;
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

  microring #(
      .waves_t(WAVES_TYPE),
      /*.ResonanceWavelength(i_wvl_ring),*/
      .FWHM(1.0),
      .TuningFullScale(10.0)
  ) microring (
      .i_phot_waves(waves_in),
      .i_real_wvl_ring(i_wvl_ring),
      .i_real_tuning_dist(0.0),  // No tuning for now
      .i_real_temperature(0.0),  // No temperature sensitivity for now
      .o_phot_waves_drop(waves_drop),
      .o_phot_waves_thru(waves_thru)
  );

  photodetector #(
      .waves_t(WAVES_TYPE)
  ) pd_drop (
      .i_phot_waves  (waves_drop),
      .o_real_current(o_pwr_drop)
  );

  photodetector #(
      .waves_t(WAVES_TYPE)
  ) pd_thru (
      .i_phot_waves  (waves_thru),
      .o_real_current(o_pwr_thru)
  );

  adc #(
      .ADC_WIDTH(`ADC_WIDTH),
      .FullScaleRange(1.0)
  ) adc_thru (
      .i_ana(o_pwr_thru),
      .o_dig(o_adc_thru)
  );

  adc #(
      .ADC_WIDTH(`ADC_WIDTH),
      .FullScaleRange(1.0)
  ) adc_drop (
      .i_ana(o_pwr_drop),
      .o_dig(o_adc_drop)
  );

  tuner_pwr_detect_phy pwr_thru_detect (
      .i_clk(i_clk),
      .i_rst(i_rst),
      .i_dig_ring_pwr(o_adc_thru),
      /*.i_dig_pwr_read_val(1'b1),
       *.o_dig_pwr_read_rdy(),
       *.o_dig_pwr_detect_val(o_dig_pwr_thru_detect_val),
       *.i_dig_pwr_detect_rdy(1'b1),
       *.o_dig_ring_pwr_detected(o_dig_pwr_thru_detect)*/
      .pwr_detect_if(pwr_detect_if)
  );
  // ----------------------------------------------------------------------

endmodule

`default_nettype wire

