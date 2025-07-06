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
`define NUM_CHANNEL 2

import wdm_pkg::*;
import tuner_phy_pkg::*;

module dut (
    input var logic i_clk,
    input var logic i_rst,

    // input signals
    input var real i_pwr,
    input var real i_wvl_ls  [  `NUM_WAVES],
    input var real i_wvl_ring[`NUM_CHANNEL],

    // output signals
    output real o_pwr_thru,
    output real o_pwr_drop[`NUM_CHANNEL],

    /*input var logic [`DAC_WIDTH-1:0] i_dac_tune,*/
    output logic [`ADC_WIDTH-1:0] o_adc_thru,
    output logic [`ADC_WIDTH-1:0] o_adc_drop[`NUM_CHANNEL],
    output logic [`DAC_WIDTH-1:0] o_dac_tune[`NUM_CHANNEL],

    output logic o_dig_pwr_drop_detect_val[`NUM_CHANNEL],
    output logic [`ADC_WIDTH-1:0] o_dig_pwr_drop_detected[`NUM_CHANNEL],

    input logic i_dig_search_trig_val[`NUM_CHANNEL],
    input logic i_dig_search_peaks_rdy[`NUM_CHANNEL],
    output logic o_dig_search_peaks_val[`NUM_CHANNEL],
    input logic [`DAC_WIDTH-1:0] i_dig_ring_tune_start[`NUM_CHANNEL],
    input logic [`DAC_WIDTH-1:0] i_dig_ring_tune_end[`NUM_CHANNEL],
    input logic [`DAC_WIDTH-1:0] i_dig_ring_tune_stride[`NUM_CHANNEL],

    // peak detect signal and collected tuner codes for codes
    output logic [`DAC_WIDTH-1:0] o_dig_ring_tune_peaks[`NUM_CHANNEL][`NUM_TARGET],
    output logic [`ADC_WIDTH-1:0] o_dig_pwr_detected_peaks[`NUM_CHANNEL][`NUM_TARGET],
    output logic [$clog2(`NUM_TARGET)-1:0] o_dig_ring_tune_peaks_cnt[`NUM_CHANNEL],

    output logic o_mon_peak_commit[`NUM_CHANNEL],
    output logic o_mon_search_active_update[`NUM_CHANNEL],
    output logic [`ADC_WIDTH-1:0] o_mon_ring_pwr[`NUM_CHANNEL],
    output logic [`DAC_WIDTH-1:0] o_mon_ring_tune[`NUM_CHANNEL],
    output tuner_phy_search_state_e o_mon_state[`NUM_CHANNEL]

);

  `DECLARE_WAVES_TYPE(2);

  // ----------------------------------------------------------------------
  // Assigns
  // ----------------------------------------------------------------------
  WAVES_TYPE waves_in;
  WAVES_TYPE waves_thru;
  WAVES_TYPE waves_drop[`NUM_CHANNEL];
  real wvls[WAVES_WIDTH];
  real pwrs[WAVES_WIDTH];

  real ana_tune[`NUM_CHANNEL];
  real real_tuning_dist[`NUM_CHANNEL];
  logic [`DAC_WIDTH-1:0] dac_tune[`NUM_CHANNEL];
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
    for (int j = 0; j < `NUM_CHANNEL; j++) begin
      real_tuning_dist[j] = ana_tune[j];
    end
  end

  assign o_dac_tune = dac_tune;
  /*assign o_dig_pwr_drop_detected = pwr_drop_detected;*/
  /*assign o_dig_pwr_drop_detect_val = pwr_detect_val;*/

  tuner_pwr_detect_if #(
      .ADC_WIDTH(`ADC_WIDTH)
  ) pwr_detect_if[`NUM_CHANNEL] (
      .i_clk(i_clk),
      .i_rst(i_rst)
  );
  /*assign pwr_detect_if.read_val = 1'b1;
   *assign pwr_detect_if.detect_rdy = 1'b1;
   *assign o_dig_pwr_drop_detected = pwr_detect_if.detect_val;
   *assign o_dig_pwr_thru_detect = pwr_detect_if.detect_data;*/
  // assignments for each channel are handled in the generate block

  tuner_search_if #(
      .ADC_WIDTH (`ADC_WIDTH),
      .DAC_WIDTH (`DAC_WIDTH),
      .NUM_TARGET(`NUM_TARGET)
  ) search_if[`NUM_CHANNEL] (
      .i_clk(i_clk),
      .i_rst(i_rst)
  );

  tuner_ctrl_arb_if #(
      .ADC_WIDTH(`ADC_WIDTH),
      .DAC_WIDTH(`DAC_WIDTH)
  ) ctrl_arb_if[`NUM_CHANNEL] ();
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

  /*microring #(
   *    .waves_t(WAVES_TYPE),
   *    [>.ResonanceWavelength(i_wvl_ring),<]
   *    .FWHM(0.2),
   *    .TuningFullScale(10.0)
   *) microring (
   *    .i_phot_waves(waves_in),
   *    .i_real_wvl_ring(i_wvl_ring),
   *    .i_real_tuning_dist(ana_tune),  // No tuning for now
   *    .i_real_temperature(0.0),  // No temperature sensitivity for now
   *    .o_phot_waves_drop(waves_drop),
   *    .o_phot_waves_thru(waves_thru)
   *);*/

  microringrow #(
      .waves_t        (WAVES_TYPE),
      .NUM_CHANNEL    (`NUM_CHANNEL),
      .FWHM           (0.25),
      .TuningFullScale(10.0)
  ) microringrow (
      .i_phot_waves      (waves_in),
      .i_real_wvl_ring   (i_wvl_ring),
      .i_real_tuning_dist(real_tuning_dist),
      .i_real_temperature('{default: 0.0}),   // No temperature sensitivity for now
      .o_phot_waves_drop (waves_drop),
      .o_phot_waves_thru (waves_thru)
  );

  // Per-channel tuning and detection hardware
  generate
    for (genvar ch = 0; ch < `NUM_CHANNEL; ch++) begin : g_ring_hw
      dac #(
          .DAC_WIDTH(`DAC_WIDTH),
          .FullScaleRange(1.0)
      ) dac_tune_afe (
          .i_dig(dac_tune[ch]),
          .o_ana(ana_tune[ch])
      );

      photodetector #(
          .waves_t(WAVES_TYPE)
      ) pd_drop (
          .i_phot_waves  (waves_drop[ch]),
          .o_real_current(o_pwr_drop[ch])
      );

      adc #(
          .ADC_WIDTH(`ADC_WIDTH),
          .FullScaleRange(1000.0)
      ) adc_drop (
          .i_ana(o_pwr_drop[ch]),
          .o_dig(o_adc_drop[ch])
      );

      tuner_pwr_detect_phy pwr_drop_detect (
          .i_clk(i_clk),
          .i_rst(i_rst),
          .i_dig_ring_pwr(o_adc_drop[ch]),
          .pwr_detect_if(pwr_detect_if[ch])
      );

      tuner_ctrl_arb_phy ctrl_arb (
          .i_clk(i_clk),
          .i_rst(i_rst),
          .pwr_detect_if(pwr_detect_if[ch]),
          .ctrl_arb_if(ctrl_arb_if[ch]),
          .o_dig_afe_ring_tune(dac_tune[ch]),
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

          .i_dig_ring_tune_start(i_dig_ring_tune_start[ch]),
          .i_dig_ring_tune_end(i_dig_ring_tune_end[ch]),
          .i_dig_ring_tune_stride(i_dig_ring_tune_stride[ch]),

          .ctrl_arb_if(ctrl_arb_if[ch]),
          .search_if  (search_if[ch])
      );

      assign search_if[ch].trig_val         = i_dig_search_trig_val[ch];
      assign search_if[ch].peaks_rdy        = i_dig_search_peaks_rdy[ch];
      assign o_dig_search_peaks_val[ch]     = search_if[ch].peaks_val;
      assign o_dig_ring_tune_peaks[ch]      = search_if[ch].ring_tune_peaks;
      assign o_dig_pwr_detected_peaks[ch]   = search_if[ch].pwr_peaks;
      assign o_dig_ring_tune_peaks_cnt[ch]  = search_if[ch].peaks_cnt;

      assign o_mon_peak_commit[ch]          = search_if[ch].mon_peak_commit;
      assign o_mon_search_active_update[ch] = search_if[ch].mon_search_active_update;
      assign o_mon_ring_pwr[ch]             = search_if[ch].mon_ring_pwr;
      assign o_mon_ring_tune[ch]            = search_if[ch].mon_ring_tune;
      assign o_mon_state[ch]                = search_if[ch].mon_state;

      assign o_dig_pwr_drop_detected[ch]    = pwr_detect_if[ch].detect_data;
      assign o_dig_pwr_drop_detect_val[ch]  = pwr_detect_if[ch].detect_val;
    end
  endgenerate

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

  // ----------------------------------------------------------------------

endmodule

`default_nettype wire

