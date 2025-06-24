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
//// Offset determined to be ~-64~+64 around the peak, however, ideally it
//// should be determined from the search phase, and min-spacing between the
//// laser tones
//
//// When the peak code is small, you can either:
//// 1) start local search from 0
//// 2) limit the min search code to non-zero, so that the found peaks are
//// automatically offsetted
//
//// current assumes that the initial wavelength is on "red" side only
//// implement *unlock* by locking to low power e.g., 10%
//// TODO: local search to dynamically determine the target via interface with
//// search_phy
//// TODO: gear shift?
//module tuner_lock_phy #(
//    parameter int DAC_WIDTH = 8,
//    parameter int ADC_WIDTH = 8,
//    parameter logic [DAC_WIDTH-1:0] DZ_SIZE = 4
//) (
//    input var logic i_clk,
//    input var logic i_rst,
//
//    // lock config
//    // expected to set start by offsetting the peak target to red-side
//    input var logic [DAC_WIDTH-1:0] i_dig_ring_tune_start,
//    // end is not used if local search is not enabled
//    input var logic [DAC_WIDTH-1:0] i_dig_ring_tune_end,
//    input var logic [ADC_WIDTH-1:0] i_dig_ring_pwr_peak,
//    input var logic [3:0] i_dig_ring_pwr_peak_ratio,
//
//    input var logic i_cfg_local_search_en,
//
//    // Power Detector Interface
//    tuner_pwr_detect_if.consumer pwr_detect_if,
//
//    // Tuner AFE Interface
//    output logic [DAC_WIDTH-1:0] o_dig_ring_tune,
//
//    // Tuner Controller Interface
//    // consumer of trigger
//    input var logic i_dig_lock_trig_val,
//    output logic o_dig_lock_trig_rdy,
//
//    // producer of lock done
//    output logic o_dig_lock_done_val,
//    input var logic i_dig_lock_done_rdy,
//
//    // consumer of track
//    input var logic i_dig_lock_track_val,
//    output logic o_dig_lock_track_rdy
//
//);
//  // ----------------------------------------------------------------------
//  // Possible mode-of-operations:
//  // 1. Run local search to locate the target again, or use the provided config
//  // 2. Dynamic slope determination, or simple PI control assuming red-side
//  // 3. Lock-to-max/min, or lock-to-target
//  // Current implementation chooses 1. provided cfg, 2. slope & PI and 3. LtT
//  // 2 for LOCK_ACTIVE, 3 for LOCK_DONE
//  // ----------------------------------------------------------------------
//
//  // If slope & power level comparison mismatches, then ideally should re-tr
//  // re-trigger either local search or global search, but need to first esca
//  // escape to the corresponding ERROR state
//
//  // Local search should leverage Search PHY logic, slope detection should
//  // have a separate low-overhead module
//
//  // ----------------------------------------------------------------------
//  // Internal States and Parameters
//  // ----------------------------------------------------------------------
//  typedef tuner_phy_detect_if_state_e lock_active_state_e;
//
//  // helper states (lock active/inactive)
//  typedef enum logic {
//    LOCK_ACTIVE   = 1'b1,
//    LOCK_INACTIVE = 1'b0
//  } lock_active_t;
//  // ----------------------------------------------------------------------
//
//  // ----------------------------------------------------------------------
//  // Signals
//  // ----------------------------------------------------------------------
//  tuner_phy_lock_state_e state, state_next;
//
//  logic lock_trig_fire;
//  logic lock_done_fire;
//
//  lock_active_state_e lock_active_state, lock_active_state_next;
//
//  logic pwr_read_fire;
//  logic pwr_detect_fire;
//  lock_active_t is_lock_active;
//  logic lock_active_update;
//
//  logic [DAC_WIDTH-1:0] ring_pwr_tgt;
//  // ----------------------------------------------------------------------
//
//  // ----------------------------------------------------------------------
//  // Assigns
//  // ----------------------------------------------------------------------
//
//  // FIXME: lightweight alternative
//  assign ring_pwr_tgt = i_dig_ring_pwr_peak * i_dig_ring_pwr_peak_ratio / 16;
//
//  // ----------------------------------------------------------------------
//
//  // TODO: finish
//  // ----------------------------------------------------------------------
//  // State Machine
//  // ----------------------------------------------------------------------
//  assign o_dig_lock_trig_rdy = (state == LOCK_IDLE) || (state == LOCK_DONE);
//  assign o_dig_lock_done_val = (state == LOCK_DONE);
//
//  assign lock_trig_fire = o_dig_lock_trig_rdy && i_dig_lock_trig_val;
//  assign lock_done_fire = o_dig_lock_done_val && i_dig_lock_done_rdy;
//
//  // State machine
//  always_ff @(posedge i_clk or posedge i_rst) begin
//    if (i_rst) begin
//      state <= LOCK_IDLE;
//    end
//    else begin
//      state <= state_next;
//    end
//  end
//
//  always_comb begin
//    case (state)
//      LOCK_IDLE: state_next = lock_trig_fire ? LOCK_INIT : state;
//      LOCK_INIT: state_next = LOCK_INIT;
//      LOCK_DONE: state_next = lock_done_fire ? LOCK_TRACK : state;
//      /*LOCK_TRACK: state_next = */
//      LOCK_ERROR: state_next = state;
//      default: state_next = state;
//    endcase
//  end
//  // ----------------------------------------------------------------------
//
//  // ----------------------------------------------------------------------
//  // LOCK_ACTIVE
//  // ----------------------------------------------------------------------
//  // Combinationally determine if the current state is *lock_active*
//  // If LOCK_IDLE/LOCK_ERROR/DONE then is_lock_active is false
//  // If LOCK_INIT/LOCK_TRACK then is_lock_active is true
//  always_comb begin
//    case (state)
//      LOCK_INIT, LOCK_TRACK: is_lock_active = LOCK_ACTIVE;
//      LOCK_IDLE, LOCK_DONE, LOCK_ERROR: is_lock_active = LOCK_INACTIVE;
//      default: is_lock_active = LOCK_INACTIVE;
//    endcase
//  end
//
//  // Power detection logic
//  assign pwr_detect_if.read_val = (is_lock_active == LOCK_ACTIVE) && (lock_active_state == PWR_READ);
//  assign pwr_detect_if.detect_rdy = (is_lock_active == LOCK_ACTIVE) && (lock_active_state == PWR_DETECT);
//
//  assign pwr_read_fire = pwr_detect_if.get_read_ack();
//  assign pwr_detect_fire = pwr_detect_if.get_detect_ack();
//
//  always_ff @(posedge i_clk or posedge i_rst) begin
//    if (i_rst) begin
//      lock_active_state <= PWR_READ;
//    end
//    else begin
//      lock_active_state <= lock_active_state_next;
//    end
//  end
//
//  always_comb begin
//    lock_active_state_next = lock_active_state;
//    if (is_lock_active == LOCK_ACTIVE) begin
//      case (lock_active_state)
//        PWR_READ: if (pwr_read_fire) lock_active_state_next = PWR_DETECT;
//        PWR_DETECT: if (pwr_detect_fire) lock_active_state_next = PWR_READ;
//        default: lock_active_state_next = PWR_READ;
//      endcase
//    end
//  end
//
//  // All update logics at LOCK_ACTIVE are triggered at pwr_detect_fire
//  assign lock_active_update = (is_lock_active == LOCK_ACTIVE) && pwr_detect_fire;
//  // ----------------------------------------------------------------------
//
//
//endmodule
//
//`default_nettype wire

