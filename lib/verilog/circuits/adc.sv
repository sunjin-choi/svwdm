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

module adc #(
    parameter int ADC_WIDTH = 8,
    parameter real FullScaleRange = 1.0
) (

    input var real i_ana,
    output logic [ADC_WIDTH-1:0] o_dig
);

  /* verilator lint_off REALCVT */
  integer tmp_int_out = $floor(i_ana * (2 ** ADC_WIDTH - 1) / FullScaleRange);
  /* verilator lint_off WIDTHTRUNC */
  /*assign o_dig = tmp_int_out & ((1 << ADC_WIDTH) - 1);*/
  // If it hits the upper limit, it will be truncated to the maximum value.
  always_comb begin
    if (tmp_int_out < 0) begin
      o_dig = '0;  // If the input is negative, output zero.
    end
    else if (tmp_int_out >= (1 << ADC_WIDTH)) begin
      o_dig = (1 << ADC_WIDTH) - 1;  // If it exceeds the maximum value, output the maximum value.
    end
    else begin
      o_dig = tmp_int_out;
    end
  end

endmodule

`default_nettype wire

