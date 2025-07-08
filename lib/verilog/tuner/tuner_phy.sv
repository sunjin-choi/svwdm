//==============================================================================
// Author: Sunjin Choi
// Description: Top-level PHY module that integrates Search, Lock, and Control
//              Arbitration PHYs.
// Signals:
// Note:
// Variable naming conventions:
//    signals => snake_case
//    Parameters (aliasing signal values) => SNAKE_CASE with all caps
//    Module Parameters => ALL_CAPS_SNAKE_CASE
//    Local Parameters => CamelCase
//==============================================================================

// verilog_format: off
`timescale 1ns/1ps
`default_nettype none
// verilog_format: on

// Temporary hack
import tuner_phy_pkg::*;

module tuner_phy #(
    parameter int DAC_WIDTH = 8,
    parameter int ADC_WIDTH = 8,
    parameter int NUM_TARGET = 8,
    // Search PHY Parameters
    parameter int SEARCH_PEAK_WINDOW_HALFSIZE = 4,
    parameter int SEARCH_PEAK_THRES = 2,
    // Lock PHY Parameters
    parameter int LOCK_DELTA_WINDOW_SIZE = 4,
    parameter int LOCK_PWR_DELTA_THRES = 2,
    parameter int LOCK_TUNE_STRIDE = 0
) (
    // input signals
    input var logic i_clk,
    input var logic i_rst,
    input var logic [ADC_WIDTH-1:0] i_dig_ring_pwr,

    // Config Inputs for Search/Lock
    input var logic [DAC_WIDTH-1:0] i_cfg_ring_tune_start,
    input var logic [DAC_WIDTH-1:0] i_cfg_ring_tune_end,
    input var logic [$clog2(DAC_WIDTH)-1:0] i_cfg_ring_tune_stride,
    input var logic [3:0] i_cfg_ring_pwr_peak_ratio,
    input var logic [ADC_WIDTH-1:0] i_cfg_pwr_peak,
    input var logic [DAC_WIDTH-1:0] i_cfg_ring_tune_peak,

    // Interfaces to the main controller
    tuner_search_if.producer search_if,
    tuner_lock_if.producer   lock_if,

    // output signals
    output logic [DAC_WIDTH-1:0] o_dig_ring_tune,
    output tuner_phy_search_state_e o_dig_search_state_mon,
    output tuner_phy_lock_state_e o_dig_lock_state_mon,
    output logic o_dig_search_err,
    output logic o_dig_lock_err
);
  /*import tuner_phy_pkg::*;*/

  // ----------------------------------------------------------------------
  // Interfaces
  // ----------------------------------------------------------------------
  tuner_pwr_detect_if #(
      .ADC_WIDTH(ADC_WIDTH)
  ) pwr_detect_if (
      .i_clk(i_clk),
      .i_rst(i_rst)
  );

  tuner_ctrl_arb_if #(
      .DAC_WIDTH(DAC_WIDTH),
      .ADC_WIDTH(ADC_WIDTH)
  ) ctrl_arb_if (
      .i_clk(i_clk),
      .i_rst(i_rst)
  );
  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // Signals
  // ----------------------------------------------------------------------
  logic [DAC_WIDTH-1:0] search_phy_ring_tune;
  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // Instantiations
  // ----------------------------------------------------------------------
  tuner_pwr_detect_phy pwr_detect_phy_inst (
      .i_clk(i_clk),
      .i_rst(i_rst),
      .i_dig_ring_pwr(i_dig_ring_pwr),
      .pwr_detect_if(pwr_detect_if.producer)
  );

  tuner_ctrl_arb_phy ctrl_arb_phy_inst (
      .i_clk(i_clk),
      .i_rst(i_rst),
      .pwr_detect_if(pwr_detect_if.consumer),
      .ctrl_arb_if(ctrl_arb_if.consumer),
      .o_dig_afe_ring_tune(o_dig_ring_tune),
      .i_afe_ring_tune_rdy(1'b1),
      .o_afe_ring_tune_val()
  );

  tuner_search_phy #(
      .DAC_WIDTH(DAC_WIDTH),
      .ADC_WIDTH(ADC_WIDTH),
      .NUM_TARGET(NUM_TARGET),
      .SEARCH_PEAK_WINDOW_HALFSIZE(SEARCH_PEAK_WINDOW_HALFSIZE),
      .SEARCH_PEAK_THRES(SEARCH_PEAK_THRES)
  ) search_phy_inst (
      .i_clk(i_clk),
      .i_rst(i_rst),

      .i_dig_ring_tune_start(i_cfg_ring_tune_start),
      .i_dig_ring_tune_end(i_cfg_ring_tune_end),
      .i_dig_ring_tune_stride(i_cfg_ring_tune_stride),

      .ctrl_arb_if(ctrl_arb_if.producer),
      .search_if(search_if),
      .o_dig_ring_tune(search_phy_ring_tune)
  );

  tuner_lock_phy #(
      .DAC_WIDTH(DAC_WIDTH),
      .ADC_WIDTH(ADC_WIDTH),
      .LOCK_DELTA_WINDOW_SIZE(LOCK_DELTA_WINDOW_SIZE),
      .LOCK_PWR_DELTA_THRES(LOCK_PWR_DELTA_THRES),
      .LOCK_TUNE_STRIDE(LOCK_TUNE_STRIDE)
  ) lock_phy_inst (
      .i_clk(i_clk),
      .i_rst(i_rst),

      .i_cfg_ring_tune_start(i_cfg_ring_tune_start),
      .i_cfg_ring_pwr_peak_ratio(i_cfg_ring_pwr_peak_ratio),
      .i_dig_pwr_peak(i_cfg_pwr_peak),
      .i_dig_ring_tune_peak(i_cfg_ring_tune_peak),

      .ctrl_arb_if(ctrl_arb_if.producer),
      .lock_if(lock_if)
  );
  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // Monitor Logic
  // ----------------------------------------------------------------------
  assign o_dig_search_state_mon = search_if.mon_state;
  assign o_dig_lock_state_mon = lock_if.mon_state;

  // No error logic implemented yet
  assign o_dig_search_err = 1'b0;
  assign o_dig_lock_err = 1'b0;
  // ----------------------------------------------------------------------

endmodule

`default_nettype wire

