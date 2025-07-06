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

`define DAC_WIDTH 8
`define ADC_WIDTH 8
`define NUM_TARGET 4
`define NUM_WAVES 2

import wdm_pkg::*;
import tuner_phy_pkg::*;

module dut (
    input var logic i_clk,
    input var logic i_rst,

    // input signals
    input var real i_pwr,
    input var real i_wvl_ls  [`NUM_WAVES],
    input var real i_wvl_ring,

    // output signals
    output real o_pwr_thru,
    output real o_pwr_drop,

    /*input var logic [`DAC_WIDTH-1:0] i_dac_tune,*/
    output logic [`ADC_WIDTH-1:0] o_adc_thru,
    output logic [`ADC_WIDTH-1:0] o_adc_drop,
    output logic [`DAC_WIDTH-1:0] o_dac_tune,

    output logic o_dig_pwr_drop_detect_val,
    output logic [`ADC_WIDTH-1:0] o_dig_pwr_drop_detected,

    input logic i_dig_search_trig_val,
    input logic i_dig_search_peaks_rdy,
    output logic o_dig_search_peaks_val,
    input logic [`DAC_WIDTH-1:0] i_dig_ring_tune_start,
    input logic [`DAC_WIDTH-1:0] i_dig_ring_tune_end,
    input logic [`DAC_WIDTH-1:0] i_dig_ring_tune_stride,

    // peak detect signal and collected tuner codes for codes
    output logic [`DAC_WIDTH-1:0] o_dig_ring_tune_peaks[`NUM_TARGET],
    output logic [`ADC_WIDTH-1:0] o_dig_pwr_detected_peaks[`NUM_TARGET],
    output logic [$clog2(`NUM_TARGET)-1:0] o_dig_ring_tune_peaks_cnt,

    output logic o_mon_peak_commit,
    output logic o_mon_search_active_update,
    output logic [`ADC_WIDTH-1:0] o_mon_ring_pwr,
    output logic [`DAC_WIDTH-1:0] o_mon_ring_tune,
    output tuner_phy_search_state_e o_mon_state

);

  `DECLARE_WAVES_TYPE(2);

  // ----------------------------------------------------------------------
  // Assigns
  // ----------------------------------------------------------------------
  WAVES_TYPE waves_in;
  WAVES_TYPE waves_thru;
  WAVES_TYPE waves_drop;
  real wvls[WAVES_WIDTH];
  real pwrs[WAVES_WIDTH];

  real ana_tune;
  logic [`DAC_WIDTH-1:0] dac_tune;
  /*logic [`ADC_WIDTH-1:0] pwr_drop_detected;*/

  /*logic pwr_read_rdy;
   *logic pwr_read_val;
   *logic pwr_detect_val;
   *logic pwr_detect_rdy;*/

  always_comb begin
    for (int i = 0; i < WAVES_WIDTH; i++) begin
      wvls[i] = i_wvl_ls[i];
      pwrs[i] = i_pwr;
    end
  end

  assign o_dac_tune = dac_tune;
  /*assign o_dig_pwr_drop_detected = pwr_drop_detected;*/
  /*assign o_dig_pwr_drop_detect_val = pwr_detect_val;*/

  tuner_pwr_detect_if #(
      .ADC_WIDTH(`ADC_WIDTH)
  ) pwr_detect_if (
      .i_clk(i_clk),
      .i_rst(i_rst)
  );
  /*assign pwr_detect_if.read_val = 1'b1;
   *assign pwr_detect_if.detect_rdy = 1'b1;
   *assign o_dig_pwr_drop_detected = pwr_detect_if.detect_val;
   *assign o_dig_pwr_thru_detect = pwr_detect_if.detect_data;*/
  assign o_dig_pwr_drop_detected   = pwr_detect_if.detect_data;
  assign o_dig_pwr_drop_detect_val = pwr_detect_if.detect_val;

  tuner_search_if #(
      .ADC_WIDTH (`ADC_WIDTH),
      .DAC_WIDTH (`DAC_WIDTH),
      .NUM_TARGET(`NUM_TARGET)
  ) search_if (
      .i_clk(i_clk),
      .i_rst(i_rst)
  );

  assign search_if.trig_val = i_dig_search_trig_val;
  assign search_if.peaks_rdy = i_dig_search_peaks_rdy;
  assign o_dig_search_peaks_val = search_if.peaks_val;
  assign o_dig_ring_tune_peaks = search_if.ring_tune_peaks;
  assign o_dig_pwr_detected_peaks = search_if.pwr_peaks;
  assign o_dig_ring_tune_peaks_cnt = search_if.peaks_cnt;

  assign o_mon_peak_commit = search_if.mon_peak_commit;
  assign o_mon_search_active_update = search_if.mon_search_active_update;
  assign o_mon_ring_pwr = search_if.mon_ring_pwr;
  assign o_mon_ring_tune = search_if.mon_ring_tune;
  assign o_mon_state = search_if.mon_state;

  tuner_ctrl_arb_if #(
      .ADC_WIDTH(`ADC_WIDTH),
      .DAC_WIDTH(`DAC_WIDTH)
  ) ctrl_arb_if ();
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
      .FWHM(0.2),
      .TuningFullScale(10.0)
  ) microring (
      .i_phot_waves(waves_in),
      .i_real_wvl_ring(i_wvl_ring),
      .i_real_tuning_dist(ana_tune),  // No tuning for now
      .i_real_temperature(0.0),  // No temperature sensitivity for now
      .o_phot_waves_drop(waves_drop),
      .o_phot_waves_thru(waves_thru)
  );

  dac #(
      .DAC_WIDTH(`DAC_WIDTH),
      .FullScaleRange(1.0)
  ) dac_tune_afe (
      .i_dig(dac_tune),
      .o_ana(ana_tune)
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

  tuner_pwr_detect_phy pwr_drop_detect (
      .i_clk(i_clk),
      .i_rst(i_rst),
      .i_dig_ring_pwr(o_adc_drop),
      .pwr_detect_if(pwr_detect_if)
  );

  tuner_ctrl_arb_phy ctrl_arb (
      .i_clk(i_clk),
      .i_rst(i_rst),
      .pwr_detect_if(pwr_detect_if),
      .ctrl_arb_if(ctrl_arb_if),
      .o_dig_afe_ring_tune(dac_tune),
      .i_afe_ring_tune_rdy(1'b1),
      .o_afe_ring_tune_val()
  );

  tuner_search_phy #(
      .DAC_WIDTH (`DAC_WIDTH),
      .ADC_WIDTH (`ADC_WIDTH),
      .NUM_TARGET(`NUM_TARGET)
  ) drop_search (
      .i_clk(i_clk),
      .i_rst(i_rst),

      .i_dig_ring_tune_start(i_dig_ring_tune_start),
      .i_dig_ring_tune_end(i_dig_ring_tune_end),
      .i_dig_ring_tune_stride(i_dig_ring_tune_stride),

      /*      .pwr_detect_if(pwr_detect_if),
 *
 *      .o_dig_ring_tune(dac_tune),*/

      /*      .i_dig_search_trig_val(i_dig_search_trig_val),
 *      .o_dig_search_trig_rdy(),
 *
 *      .o_dig_search_peaks_val(o_dig_search_peaks_val),
 *      .i_dig_search_peaks_rdy(i_dig_search_peaks_rdy),
 *
 *      .o_dig_ring_tune_peaks(o_dig_ring_tune_peaks),
 *      .o_dig_pwr_detected_peaks(o_dig_pwr_detected_peaks),
 *      .o_dig_ring_tune_peaks_cnt(o_dig_ring_tune_peaks_cnt),*/

      .ctrl_arb_if(ctrl_arb_if),

      .search_if(search_if)

      /*.o_mon_peak_commit(o_mon_peak_commit),
       *.o_mon_search_active_update(o_mon_search_active_update),
       *.o_mon_ring_pwr(o_mon_ring_pwr),
       *.o_mon_ring_tune(o_mon_ring_tune),
       *.o_mon_state(o_mon_state)*/
  );

  // ----------------------------------------------------------------------

endmodule

`default_nettype wire

