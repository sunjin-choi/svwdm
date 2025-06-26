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

interface tuner_pwr_detect_if #(
    parameter int ADC_WIDTH = 8
) (
    input logic i_clk,
    input logic i_rst
);
  import tuner_phy_pkg::*;

  // ----------------------------------------------------------------------
  // Signals
  // ----------------------------------------------------------------------
  logic read_val;
  logic read_rdy;

  logic detect_rdy;
  logic detect_val;
  logic [ADC_WIDTH-1:0] detect_data;

  /*typedef enum logic {
   *  PWR_READ,
   *  PWR_DETECT
   *} pwr_detect_state_e;*/
  /*pwr_detect_state_e pwr_detect_state, pwr_detect_state_next;*/
  tuner_phy_detect_if_state_e pwr_detect_state, pwr_detect_state_next;

  // Interface arbitration logic signals - used by consumer
  logic pwr_detect_refresh;
  logic pwr_detect_active;
  logic pwr_detect_update;
  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // APIs
  // ----------------------------------------------------------------------
  function automatic logic get_read_ack();
    return read_val & read_rdy;
  endfunction

  function automatic logic get_detect_ack();
    return detect_val & detect_rdy;
  endfunction
  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // Interface Logic
  // ----------------------------------------------------------------------
  // Break rdy/val interface abstraction to simplify consumer logic
  // TODO: if add consumer-side rdy/val here, possible to implement more
  // controls?
  assign read_val   = pwr_detect_active && (pwr_detect_state == PWR_READ);
  assign detect_rdy = pwr_detect_active && (pwr_detect_state == PWR_DETECT);

  // Internal Read <-> Detect state logic
  always_ff @(posedge i_clk or posedge i_rst) begin
    if (i_rst) begin
      pwr_detect_state <= PWR_READ;
    end
    else if (pwr_detect_refresh) begin
      // If the consumer requests a refresh, we switch to the read state
      pwr_detect_state <= PWR_READ;
    end
    else begin
      pwr_detect_state <= pwr_detect_state_next;
    end
  end

  // Advance states only when pwr_detect_active is high
  // Each sub-state is responsible for triggering the next state at "fire"
  always_comb begin
    pwr_detect_state_next = pwr_detect_state;
    if (pwr_detect_active) begin
      case (pwr_detect_state)
        PWR_READ: if (get_read_ack()) pwr_detect_state_next = PWR_DETECT;
        PWR_DETECT: if (get_detect_ack()) pwr_detect_state_next = PWR_READ;
        default: pwr_detect_state_next = PWR_READ;  // Default to read state
      endcase
    end
  end

  // All consumer logics that depends on the power detect are triggered at pwr_detect_fire
  // This signal is a single clock-width pulse
  assign pwr_detect_update = pwr_detect_active && get_detect_ack();
  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // Modports
  // ----------------------------------------------------------------------
  modport producer(
      input read_val,
      input detect_rdy,
      output read_rdy,
      output detect_val,
      output detect_data,
      import get_read_ack,
      import get_detect_ack
  );

  modport consumer(
      // Break rdy/val interface abstraction to simplify consumer logic
      /*output read_val,
       *output detect_rdy,*/
      input read_rdy,
      input detect_val,
      input detect_data,
      // Consumer-side arbitration interface
      output pwr_detect_refresh,
      output pwr_detect_active,
      input pwr_detect_update,
      import get_read_ack,
      import get_detect_ack
  );
  // ----------------------------------------------------------------------

endinterface

