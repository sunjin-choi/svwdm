//==============================================================================
// Author: Sunjin Choi
// Description: 
// Signals:
// Note: Wait for WAIT_CYCLES, then detect power from the microring via
// averaging for NUM_PWR_DETECT cycles.
// Variable naming conventions:
//    signals => snake_case
//    Parameters (aliasing signal values) => SNAKE_CASE with all caps
//    Parameters (not aliasing signal values) => CamelCase
//==============================================================================

// verilog_format: off
`timescale 1ns/1ps
`default_nettype none
// verilog_format: on

// TODO: implement a lightweight pwr threshold detector
module tuner_pwr_detect_phy #(
    parameter int ADC_WIDTH = 8,
    parameter int WAIT_CYCLE = 4,
    parameter int NUM_PWR_DETECT = 1
) (
    input var logic i_clk,
    input var logic i_rst,

    input var logic [ADC_WIDTH-1:0] i_dig_ring_pwr,

    /*    // consumer of power read
 *    input var logic i_dig_pwr_read_val,
 *    output logic o_dig_pwr_read_rdy,
 *
 *    // producer of power detect
 *    output logic o_dig_pwr_detect_val,
 *    input var logic i_dig_pwr_detect_rdy,
 *    output logic [ADC_WIDTH-1:0] o_dig_ring_pwr_detected*/

    tuner_pwr_detect_if.producer pwr_detect_if

);
  /*import tuner_pkg::*;*/
  import tuner_phy_pkg::*;

  // ----------------------------------------------------------------------
  // Signals
  // ----------------------------------------------------------------------
  /*state_t state, state_next;*/
  tuner_phy_detect_state_e state, state_next;

  logic [$clog2(WAIT_CYCLE+1)-1:0] wait_cnt;
  logic [$clog2(NUM_PWR_DETECT+1)-1:0] detect_cnt;
  logic [(ADC_WIDTH+$clog2(NUM_PWR_DETECT))-1:0] acc_pwr;

  logic pwr_read_fire;
  logic pwr_detect_fire;
  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // Assigns
  // ----------------------------------------------------------------------
  // When pwr_read_fire goes high, we start entering WAIT state where:
  // - wait_cnt counts up to WAIT_CYCLE
  // - acc_pwr is reset to 0
  /*assign o_dig_pwr_read_rdy = (state == DETECT_IDLE) || (state == DETECT_DONE);
   *assign pwr_read_fire = i_dig_pwr_read_val && o_dig_pwr_read_rdy;*/
  assign pwr_detect_if.read_rdy = (state == DETECT_IDLE) || (state == DETECT_DONE);
  assign pwr_read_fire = pwr_detect_if.get_read_ack();

  // detect pwr is combinationally connected to acc_pwr when it is "fired"
  /*assign o_dig_pwr_detect_val = state == DETECT_DONE;
   *assign pwr_detect_fire = o_dig_pwr_detect_val && i_dig_pwr_detect_rdy;
   *assign o_dig_ring_pwr_detected = pwr_detect_fire ? (acc_pwr / NUM_PWR_DETECT) : '0;*/
  assign pwr_detect_if.detect_val = (state == DETECT_DONE);
  assign pwr_detect_fire = pwr_detect_if.get_detect_ack();
  /*assign pwr_detect_if.detect_data = pwr_detect_fire ? (acc_pwr / NUM_PWR_DETECT) : '0;*/
  // TODO: pulsation is bad for SI?
  assign pwr_detect_if.detect_data = pwr_detect_fire ? (acc_pwr >> $clog2(NUM_PWR_DETECT)) : '0;

  // State machine with cycle counts
  // *Note*: when "read" is asserted, we enter the WAIT state instead of
  // ACTIVE state which is the state where we wait for ring+afe stabilization
  always_ff @(posedge i_clk or posedge i_rst) begin
    if (i_rst) begin
      state <= DETECT_IDLE;
      wait_cnt <= '0;
      detect_cnt <= '0;
    end
    else begin
      state <= state_next;
      case (state)
        DETECT_IDLE: begin
          wait_cnt   <= '0;
          detect_cnt <= '0;
        end
        DETECT_WAIT: begin
          wait_cnt   <= wait_cnt + 1;
          detect_cnt <= '0;
        end
        DETECT_ACTIVE: begin
          wait_cnt   <= '0;
          detect_cnt <= detect_cnt + 1;
        end
        DETECT_DONE: begin
          wait_cnt   <= '0;
          detect_cnt <= '0;
        end
        default: begin
          wait_cnt   <= '0;
          detect_cnt <= '0;
        end
      endcase
    end
  end

  always_comb begin
    case (state)
      DETECT_IDLE: state_next = pwr_read_fire ? DETECT_WAIT : DETECT_IDLE;
      DETECT_WAIT: state_next = (wait_cnt == WAIT_CYCLE - 1) ? DETECT_ACTIVE : DETECT_WAIT;
      DETECT_ACTIVE: state_next = (detect_cnt == NUM_PWR_DETECT - 1) ? DETECT_DONE : DETECT_ACTIVE;
      DETECT_DONE: state_next = pwr_read_fire ? DETECT_WAIT : DETECT_DONE;
      default: state_next = state;
    endcase
  end

  always_ff @(posedge i_clk or posedge i_rst) begin
    if (i_rst) begin
      acc_pwr <= '0;
    end
    else begin
      case (state)
        DETECT_IDLE: acc_pwr <= '0;
        DETECT_WAIT: acc_pwr <= '0;
        DETECT_ACTIVE: acc_pwr <= acc_pwr + i_dig_ring_pwr;
        DETECT_DONE: acc_pwr <= acc_pwr;
        default: acc_pwr <= '0;
      endcase
    end
  end
  // ----------------------------------------------------------------------

endmodule

`default_nettype wire

