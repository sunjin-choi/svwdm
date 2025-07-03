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

module timer #(
    parameter int CNT_WIDTH = 4
) (
    input var logic i_clk,
    input var logic i_rst_async,
    input var logic i_rst_sync,

    input var logic [CNT_WIDTH-1:0] i_cnt,
    input var logic i_update,

    output logic o_done

);




endmodule

`default_nettype wire

