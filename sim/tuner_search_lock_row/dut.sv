//==============================================================================
// Author: Sunjin Choi
// Description: DUT for tuner_search_lock_row simulation
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

    // Config Inputs for Search/Lock
    input var logic [`DAC_WIDTH-1:0] i_cfg_ring_tune_start[`NUM_CHANNEL],
    input var logic [`DAC_WIDTH-1:0] i_cfg_ring_tune_end[`NUM_CHANNEL],
    input var logic [$clog2(`DAC_WIDTH)-1:0] i_cfg_ring_tune_stride[`NUM_CHANNEL],
    input var logic [3:0] i_cfg_ring_pwr_peak_ratio[`NUM_CHANNEL],
    input var logic [`ADC_WIDTH-1:0] i_cfg_pwr_peak[`NUM_CHANNEL],
    input var logic [`DAC_WIDTH-1:0] i_cfg_ring_tune_peak[`NUM_CHANNEL],

    // Search Interface
    input var logic i_search_trig_val[`NUM_CHANNEL],
    output var logic o_search_trig_rdy[`NUM_CHANNEL],
    input var logic i_search_done_rdy[`NUM_CHANNEL],
    output var logic o_search_done_val[`NUM_CHANNEL],
    output var logic [`DAC_WIDTH-1:0] o_pwr_peak_tune_codes[`NUM_CHANNEL][`NUM_TARGET],
    output var logic [`ADC_WIDTH-1:0] o_pwr_peak_codes[`NUM_CHANNEL][`NUM_TARGET],
    output var logic [$clog2(`NUM_TARGET):0] o_num_peaks[`NUM_CHANNEL],

    // Lock Interface
    input var  logic i_lock_trig_val  [`NUM_CHANNEL],
    output var logic o_lock_trig_rdy  [`NUM_CHANNEL],
    input var  logic i_lock_intr_rdy  [`NUM_CHANNEL],
    output var logic o_lock_intr_val  [`NUM_CHANNEL],
    input var  logic i_lock_resume_val[`NUM_CHANNEL],
    output var logic o_lock_resume_rdy[`NUM_CHANNEL],

    // output signals
    output real o_pwr_thru,
    output real o_pwr_drop[`NUM_CHANNEL],
    output logic [`DAC_WIDTH-1:0] o_ring_tune[`NUM_CHANNEL],
    output tuner_phy_search_state_e o_search_state[`NUM_CHANNEL],
    output tuner_phy_lock_state_e o_lock_state[`NUM_CHANNEL],
    output logic o_search_err[`NUM_CHANNEL],
    output logic o_lock_err[`NUM_CHANNEL],
    output logic [`ADC_WIDTH-1:0] o_adc_thru,
    output logic [`ADC_WIDTH-1:0] o_adc_drop[`NUM_CHANNEL]
);

  `DECLARE_WAVES_TYPE(2);

  // ----------------------------------------------------------------------
  // Interfaces
  // ----------------------------------------------------------------------
  tuner_search_if #(
      .DAC_WIDTH (`DAC_WIDTH),
      .ADC_WIDTH (`ADC_WIDTH),
      .NUM_TARGET(`NUM_TARGET)
  ) search_if[`NUM_CHANNEL] (
      .i_clk(i_clk),
      .i_rst(i_rst)
  );
  tuner_lock_if #(
      .DAC_WIDTH (`DAC_WIDTH),
      .ADC_WIDTH (`ADC_WIDTH),
      .NUM_TARGET(`NUM_TARGET)
  ) lock_if[`NUM_CHANNEL] (
      .*
  );
  tuner_ctrl_arb_if #(
      .DAC_WIDTH(`DAC_WIDTH),
      .ADC_WIDTH(`ADC_WIDTH)
  ) ctrl_arb_if[`NUM_CHANNEL] (
      .*
  );
  tuner_pwr_detect_if #(
      .ADC_WIDTH(`ADC_WIDTH)
  ) pwr_detect_if[`NUM_CHANNEL] (
      .i_clk(i_clk),
      .i_rst(i_rst)
  );
  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // Signals
  // ----------------------------------------------------------------------
  WAVES_TYPE waves_in;
  WAVES_TYPE waves_thru;
  WAVES_TYPE waves_drop[`NUM_CHANNEL];
  real wvls[WAVES_WIDTH];
  real pwrs[WAVES_WIDTH];

  real ana_tune[`NUM_CHANNEL];
  real real_tuning_dist[`NUM_CHANNEL];
  logic [`DAC_WIDTH-1:0] ring_tune_dig[`NUM_CHANNEL];
  logic [`ADC_WIDTH-1:0] adc_thru;
  logic [`ADC_WIDTH-1:0] adc_drop[`NUM_CHANNEL];

  always_comb begin
    for (int i = 0; i < WAVES_WIDTH; i++) begin
      wvls[i] = i_wvl_ls[i];
      pwrs[i] = i_pwr;
    end
    for (int j = 0; j < `NUM_CHANNEL; j++) begin
      real_tuning_dist[j] = ana_tune[j];
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
      .waves_t        (WAVES_TYPE),
      .NUM_CHANNEL    (`NUM_CHANNEL),
      .FWHM           (0.25),
      .TuningFullScale(10.0)
  ) microringrow (
      .i_phot_waves      (waves_in),
      .i_real_wvl_ring   (i_wvl_ring),
      .i_real_tuning_dist(real_tuning_dist),
      .i_real_temperature('{default: 0.0}),
      .o_phot_waves_drop (waves_drop),
      .o_phot_waves_thru (waves_thru)
  );

  generate
    for (genvar ch = 0; ch < `NUM_CHANNEL; ch++) begin : g_ring_hw
      dac #(
          .DAC_WIDTH(`DAC_WIDTH),
          .FullScaleRange(1.0)
      ) dac_tune (
          .i_dig(ring_tune_dig[ch]),
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
      ) adc_drop_inst (
          .i_ana(o_pwr_drop[ch]),
          .o_dig(adc_drop[ch])
      );

      tuner_phy #(
          .DAC_WIDTH(`DAC_WIDTH),
          .ADC_WIDTH(`ADC_WIDTH),
          .NUM_TARGET(`NUM_TARGET),
          .SEARCH_PEAK_WINDOW_HALFSIZE(4),
          .SEARCH_PEAK_THRES(2),
          .LOCK_DELTA_WINDOW_SIZE(2),
          .LOCK_PWR_DELTA_THRES(2),
          .LOCK_TUNE_STRIDE(0)
      ) tuner_phy_inst (
          .i_clk(i_clk),
          .i_rst(i_rst),
          .i_dig_ring_pwr(adc_drop[ch]),
          .i_cfg_ring_tune_start(i_cfg_ring_tune_start[ch]),
          .i_cfg_ring_tune_end(i_cfg_ring_tune_end[ch]),
          .i_cfg_ring_tune_stride(i_cfg_ring_tune_stride[ch]),
          .i_cfg_ring_pwr_peak_ratio(i_cfg_ring_pwr_peak_ratio[ch]),
          .i_cfg_pwr_peak(i_cfg_pwr_peak[ch]),
          .i_cfg_ring_tune_peak(i_cfg_ring_tune_peak[ch]),
          .search_if(search_if[ch].producer),
          .lock_if(lock_if[ch].producer),
          .o_dig_ring_tune(ring_tune_dig[ch]),
          .o_dig_search_state_mon(o_search_state[ch]),
          .o_dig_lock_state_mon(o_lock_state[ch]),
          .o_dig_search_err(o_search_err[ch]),
          .o_dig_lock_err(o_lock_err[ch])
      );

      // Search Interface Logic
      assign search_if[ch].trig_val    = i_search_trig_val[ch];
      assign o_search_trig_rdy[ch]     = search_if[ch].trig_rdy;
      assign search_if[ch].peaks_rdy   = i_search_done_rdy[ch];
      assign o_search_done_val[ch]     = search_if[ch].peaks_val;
      assign o_pwr_peak_tune_codes[ch] = search_if[ch].ring_tune_peaks;
      assign o_pwr_peak_codes[ch]      = search_if[ch].pwr_peaks;
      assign o_num_peaks[ch]           = search_if[ch].peaks_cnt;

      // Lock Interface Logic
      assign lock_if[ch].trig_val      = i_lock_trig_val[ch];
      assign o_lock_trig_rdy[ch]       = lock_if[ch].trig_rdy;
      assign o_lock_intr_val[ch]       = lock_if[ch].intr_val;
      assign lock_if[ch].intr_rdy      = i_lock_intr_rdy[ch];
      assign lock_if[ch].resume_val    = i_lock_resume_val[ch];
      assign o_lock_resume_rdy[ch]     = lock_if[ch].resume_rdy;

      assign o_ring_tune[ch]           = ring_tune_dig[ch];
      assign o_adc_drop[ch]            = adc_drop[ch];
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
  ) adc_thru_inst (
      .i_ana(o_pwr_thru),
      .o_dig(adc_thru)
  );

  assign o_adc_thru = adc_thru;

endmodule

`default_nettype wire
