////==============================================================================
//// Author: Sunjin Choi
//// Description: 
//// Signals:
//// Note: 
//// Variable naming conventions:
////    signals => snake_case
////    Parameters (aliasing signal values) => SNAKE_CASE with all caps
////    Parameters (not aliasing signal values) => CamelCase
////==============================================================================
//
//// verilog_format: off
//`timescale 1ns/1ps
//`default_nettype none
//// verilog_format: on
//
//`define ADC_WIDTH 8
//`define DAC_WIDTH 8
//
//module tuner_phy #(
//    parameter logic [`DAC_WIDTH-1:0] SEARCH_STEP = 8'h01,
//    parameter logic [`DAC_WIDTH-1:0] LOCK_LOCAL_SEARCH_STEP = 8'h02,
//    parameter int LOCK_LOCAL_SEARCH_ITER = 4,
//    parameter logic [`DAC_WIDTH-1:0] LOCK_GLOBAL_SEARCH_STEP = 8'h04
//) (
//    // input signals
//    input var logic i_clk,
//    input var logic i_rst,
//    input var logic [`ADC_WIDTH-1:0] i_dig_ring_pwr,
//
//    input var logic i_dig_cmd_val,
//    output logic i_dig_cmd_rdy,
//    input var tuner_cmd_e i_dig_cmd_data,
//
//    input logic [`DAC_WIDTH-1:0] i_dig_ring_tune_init,
//
//    // output signals
//    output logic [`DAC_WIDTH-1:0] o_dig_ring_tune,
//    output tuner_state_e o_dig_state_mon,
//    output logic o_dig_state_err,
//    output logic o_dig_lock_err
//);
//  /*import tuner_pkg::*;*/
//  import tuner_phy_pkg::*;
//
//  // ----------------------------------------------------------------------
//  // Signals
//  // ----------------------------------------------------------------------
//  tuner_state_e state;
//  tuner_state_e state_next;
//
//  tuner_cmd_e cmd;
//
//  tuner_phy_search_state_e search_state;
//  tuner_phy_lock_state_e lock_state;
//
//  logic cmd_init;
//
//  logic phy_state_done;
//
//  // ----------------------------------------------------------------------
//
//  // ----------------------------------------------------------------------
//  // Assigns
//  // ----------------------------------------------------------------------
//
//  always_comb begin : state_advance
//    case (state)
//      IDLE: state_next = cmd_init ? ACTIVE : IDLE;
//      ACTIVE: state_next = 1'b0;
//      DONE: state_next = phy_state_done ? IDLE : ACTIVE;
//      ERROR: state_next = ERROR;
//      default: state_next = IDLE;
//    endcase
//  end
//
//  always_ff @(posedge i_clk or posedge i_rst) begin
//    if (i_rst) begin
//      state <= IDLE;
//    end
//    else begin
//      state <= state_next;
//    end
//  end
//
//  // ----------------------------------------------------------------------
//
//
//  function automatic logic is_phy_search_done;
//    return is_search_done(cmd, state) && (search_state == SEARCH_DONE);
//  endfunction
//
//  function automatic logic is_phy_lock_done;
//    return is_lock_done(cmd, state) && (lock_state == LOCK_DONE);
//  endfunction
//
//endmodule
//
//`default_nettype wire
//
