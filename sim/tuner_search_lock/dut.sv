//==============================================================================
// Author: Sunjin Choi
// Description: DUT for tuner_search_lock simulation
//==============================================================================

// verilog_format: off
`timescale 1ns/1ps
`default_nettype none
// verilog_format: on

`define DAC_WIDTH 8
`define ADC_WIDTH 8
`define NUM_TARGET 8

module dut (
    input var logic i_clk,
    input var logic i_rst,

    // input signals
    input var real i_pwr,
    input var real i_wvl_ls,
    input var real i_wvl_ring,

    // Config Inputs for Search/Lock
    input var logic [`DAC_WIDTH-1:0] i_cfg_ring_tune_start,
    input var logic [`DAC_WIDTH-1:0] i_cfg_ring_tune_end,
    input var logic [$clog2(`DAC_WIDTH)-1:0] i_cfg_ring_tune_stride,
    input var logic [3:0] i_cfg_ring_pwr_peak_ratio,

    input var logic [`ADC_WIDTH-1:0] i_cfg_pwr_peak,
    input var logic [`DAC_WIDTH-1:0] i_cfg_ring_tune_peak,

    // Search Interface
    input var logic i_search_trig_val,
    output var logic o_search_trig_rdy,
    input var logic i_search_done_rdy,
    output var logic o_search_done_val,
    output var logic [`DAC_WIDTH-1:0] o_pwr_peak_tune_codes[`NUM_TARGET-1:0],
    output var logic [`ADC_WIDTH-1:0] o_pwr_peak_codes[`NUM_TARGET-1:0],
    output var logic [$clog2(`NUM_TARGET):0] o_num_peaks,

    // Lock Interface
    input var  logic i_lock_trig_val,
    output var logic o_lock_trig_rdy,
    input var  logic i_lock_intr_rdy,
    output var logic o_lock_intr_val,
    input var  logic i_lock_resume_val,
    output var logic o_lock_resume_rdy,

    // output signals
    output real o_pwr_thru,
    output real o_pwr_drop,
    output logic [`DAC_WIDTH-1:0] o_ring_tune,
    output tuner_phy_search_state_e o_search_state,
    output tuner_phy_lock_state_e o_lock_state,
    output logic o_search_err,
    output logic o_lock_err,
    output logic [`ADC_WIDTH-1:0] o_adc_thru,
    output logic [`ADC_WIDTH-1:0] o_adc_drop
);
  import wdm_pkg::*;
  import tuner_phy_pkg::*;

  `DECLARE_WAVES_TYPE(1)

  // ----------------------------------------------------------------------
  // Interfaces
  // ----------------------------------------------------------------------
  tuner_search_if #(
      .DAC_WIDTH (`DAC_WIDTH),
      .ADC_WIDTH (`ADC_WIDTH),
      .NUM_TARGET(`NUM_TARGET)
  ) search_if ();
  tuner_lock_if #(
      .DAC_WIDTH (`DAC_WIDTH),
      .ADC_WIDTH (`ADC_WIDTH),
      .NUM_TARGET(`NUM_TARGET)
  ) lock_if ();
  // ----------------------------------------------------------------------


  // ----------------------------------------------------------------------
  // Signals
  // ----------------------------------------------------------------------
  WAVES_TYPE waves_in;
  WAVES_TYPE waves_thru;
  WAVES_TYPE waves_drop;
  real wvls[WAVES_WIDTH];
  real pwrs[WAVES_WIDTH];

  real ana_tune;

  logic [`ADC_WIDTH-1:0] adc_thru;
  logic [`ADC_WIDTH-1:0] adc_drop;

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

  microring #(
      .waves_t(WAVES_TYPE),
      .FWHM(1.0),
      .TuningFullScale(10.0)
  ) microring (
      .i_phot_waves(waves_in),
      .i_real_wvl_ring(i_wvl_ring),
      .i_real_tuning_dist(ana_tune),
      .i_real_temperature(0.0),
      .o_phot_waves_drop(waves_drop),
      .o_phot_waves_thru(waves_thru)
  );

  dac #(
      .DAC_WIDTH(`DAC_WIDTH),
      .FullScaleRange(1.0)
  ) dac_tune (
      .i_dig(o_ring_tune),
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
  ) adc_thru_inst (
      .i_ana(o_pwr_thru),
      .o_dig(adc_thru)
  );

  adc #(
      .ADC_WIDTH(`ADC_WIDTH),
      .FullScaleRange(1.0)
  ) adc_drop_inst (
      .i_ana(o_pwr_drop),
      .o_dig(adc_drop)
  );

  tuner_phy #(
      .DAC_WIDTH(`DAC_WIDTH),
      .ADC_WIDTH(`ADC_WIDTH),
      .NUM_TARGET(`NUM_TARGET),
      .SEARCH_PEAK_WINDOW_HALFSIZE(4),
      .SEARCH_PEAK_THRES(2),
      .LOCK_DELTA_WINDOW_SIZE(4),
      .LOCK_PWR_DELTA_THRES(2),
      .LOCK_TUNE_STRIDE(0)
  ) tuner_phy_inst (
      .i_clk(i_clk),
      .i_rst(i_rst),
      .i_dig_ring_pwr(adc_drop),
      .i_cfg_ring_tune_start(i_cfg_ring_tune_start),
      .i_cfg_ring_tune_end(i_cfg_ring_tune_end),
      .i_cfg_ring_tune_stride(i_cfg_ring_tune_stride),
      .i_cfg_ring_pwr_peak_ratio(i_cfg_ring_pwr_peak_ratio),
      .i_cfg_pwr_peak(i_cfg_pwr_peak),
      .i_cfg_ring_tune_peak(i_cfg_ring_tune_peak),
      .search_if(search_if.producer),
      .lock_if(lock_if.producer),
      .o_dig_ring_tune(o_ring_tune),
      .o_dig_search_state_mon(o_search_state),
      .o_dig_lock_state_mon(o_lock_state),
      .o_dig_search_err(o_search_err),
      .o_dig_lock_err(o_lock_err)
  );
  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // Search Interface Logic
  // ----------------------------------------------------------------------
  assign search_if.trig_val = i_search_trig_val;
  assign o_search_trig_rdy = search_if.trig_rdy;
  assign search_if.peaks_rdy = i_search_done_rdy;
  assign o_search_done_val = search_if.peaks_val;
  assign o_pwr_peak_tune_codes = search_if.ring_tune_peaks;
  assign o_pwr_peak_codes = search_if.pwr_peaks;
  assign o_num_peaks = search_if.peaks_cnt;
  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // Lock Interface Logic
  // ----------------------------------------------------------------------
  assign lock_if.trig_val = i_lock_trig_val;
  assign o_lock_trig_rdy = lock_if.trig_rdy;
  assign o_lock_intr_val = lock_if.intr_val;
  assign lock_if.intr_rdy = i_lock_intr_rdy;
  assign lock_if.resume_val = i_lock_resume_val;
  assign o_lock_resume_rdy = lock_if.resume_rdy;
  // ----------------------------------------------------------------------

  assign o_adc_thru = adc_thru;
  assign o_adc_drop = adc_drop;

endmodule

`default_nettype wire
