//==============================================================================
// Author: Sunjin Choi
// Description:
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

// Offset determined to be ~-64~+64 around the peak, however, ideally it
// should be determined from the search phase, and min-spacing between the
// laser tones

// When the peak code is small, you can either:
// 1) start local search from 0
// 2) limit the min search code to non-zero, so that the found peaks are
// automatically offsetted

// current assumes that the initial wavelength is on "red" side only
// implement *unlock* by locking to low power e.g., 10%
// TODO: local search to dynamically determine the target via interface with
// search_phy
// TODO: gear shift?
module tuner_lock_phy #(
    parameter int DAC_WIDTH = 8,
    parameter int ADC_WIDTH = 8,
    parameter int LOCK_DELTA_WINDOW_SIZE = 4
    /*parameter logic [DAC_WIDTH-1:0] DZ_SIZE = 4*/
) (
    input var logic i_clk,
    input var logic i_rst,

    // lock config
    //    // expected to set start by offsetting the peak target to red-side
    input var logic [DAC_WIDTH-1:0] i_cfg_ring_tune_start,
    input var logic [$clog2(DAC_WIDTH)-1:0] i_cfg_lock_tune_stride,
    input var logic [$clog2(LOCK_DELTA_WINDOW_SIZE + 1)-1:0] i_cfg_lock_pwr_delta_thres,
    //    // end is not used if local search is not enabled
    //    input var logic [DAC_WIDTH-1:0] i_cfg_ring_tune_end,
    //    /*input var logic [ADC_WIDTH-1:0] i_cfg_ring_pwr_peak,*/
    input var logic [3:0] i_cfg_ring_pwr_peak_ratio,

    input var logic [ADC_WIDTH-1:0] i_dig_pwr_peak,
    input var logic [DAC_WIDTH-1:0] i_dig_ring_tune_peak,

    /*input var logic i_cfg_search_en,*/

    // Tuning transaction interface
    tuner_txn_if.ctrl txn_if,

    // Tuner Controller Interface
    tuner_lock_if.producer lock_if
);
  import tuner_phy_pkg::*;

  // TODO: lock-to-target
  // TODO: simple PI (bang-bang) control
  // TODO: more configs for global/local-search and others

  // TODO: If slope & power level comparison mismatches, then ideally should re-tr
  // re-trigger either local search or global search, but need to first esca
  // escape to the corresponding ERROR state

  // ----------------------------------------------------------------------
  // Internal States and Parameters
  // ----------------------------------------------------------------------
  // This is specific to the lock scheme, which is slope detection-based
  // Runs atop the lock_active_state_e which are pwr-detect/tune substates
  typedef enum logic [2:0] {
    TRACK_DELTA,  /* Generate delta, for now a simple ramp */
    TRACK_DETECT  /* Detect the slope and decide the next tuner direction */
  } lock_track_state_e;
  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // Signals
  // ----------------------------------------------------------------------
  tuner_phy_lock_state_e state, state_next;
  localparam int LockDeltaThresWidth = $clog2(LOCK_DELTA_WINDOW_SIZE + 1);
  localparam logic [LockDeltaThresWidth-1:0] LockDeltaWindowSizeValue =
      LockDeltaThresWidth'(LOCK_DELTA_WINDOW_SIZE);
  lock_track_state_e lock_track_state, lock_track_state_next;

  logic lock_trig_fire;
  logic lock_intr_fire;
  logic lock_resume_fire;
  logic lock_restore;

  logic lock_refresh;

  logic is_session_active_state;
  logic lock_active_update;
  logic lock_delta_update;

  // delta window counter; delta_cnt count until LOCK_DELTA_WINDOW_SIZE + 1
  logic [$clog2(LOCK_DELTA_WINDOW_SIZE):0] delta_cnt;

  logic [DAC_WIDTH-1:0] ring_tune_step;
  logic [DAC_WIDTH-1:0] ring_tune;
  logic [DAC_WIDTH-1:0] ring_tune_next;
  logic [DAC_WIDTH-1:0] ring_tune_prev;
  logic [DAC_WIDTH-1:0] ring_tune_next_bb;
  logic [DAC_WIDTH-1:0] ring_tune_base;
  logic [DAC_WIDTH-1:0] ring_tune_delta;
  logic [DAC_WIDTH-1:0] ring_tune_base_next;
  logic [DAC_WIDTH-1:0] ring_tune_delta_next;
  logic [DAC_WIDTH-1:0] ring_tune_base_decided;

  // For now, only save a single peak information
  logic [ADC_WIDTH-1:0] pwr_peak;
  logic [DAC_WIDTH-1:0] ring_tune_peak;
  logic [ADC_WIDTH-1:0] pwr_tgt;

  logic [DAC_WIDTH-1:0] ring_tune_track_win[LOCK_DELTA_WINDOW_SIZE];
  logic [ADC_WIDTH-1:0] pwr_det_track_win[LOCK_DELTA_WINDOW_SIZE];
  logic [LOCK_DELTA_WINDOW_SIZE-1:0] pwr_inc_track_win;
  logic [LOCK_DELTA_WINDOW_SIZE-1:0] pwr_dec_track_win;

  logic pwr_incremented_vote;
  logic pwr_decremented_vote;
  logic [LockDeltaThresWidth-1:0] lock_pwr_delta_thres_eff;

  logic is_ctrl_active_state;
  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // Assigns
  // ----------------------------------------------------------------------
  /*assign pwr_tgt = i_dig_pwr_peak * i_cfg_ring_pwr_peak_ratio / 16;*/
  assign ring_tune_step   = (1 << i_cfg_lock_tune_stride);

  always_comb begin
    if (i_cfg_lock_pwr_delta_thres == '0) begin
      lock_pwr_delta_thres_eff = 'd1;
    end
    else if (i_cfg_lock_pwr_delta_thres > LockDeltaWindowSizeValue) begin
      lock_pwr_delta_thres_eff = LockDeltaWindowSizeValue;
    end
    else begin
      lock_pwr_delta_thres_eff = i_cfg_lock_pwr_delta_thres;
    end
  end
  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // State Machine
  // ----------------------------------------------------------------------
  assign lock_if.trig_rdy = (state == LOCK_IDLE);
  assign lock_trig_fire   = lock_if.get_trig_ack();

  // Interrupt handshake
  // Graceful stop: accept interrupt only once the current tune/measure
  // transaction has completed.
  assign lock_if.intr_rdy = (state == LOCK_ACTIVE) && txn_if.rdy;
  assign lock_intr_fire = (state == LOCK_ACTIVE) && lock_if.get_intr_ack();

  // Resume handshake
  assign lock_if.resume_rdy = (state == LOCK_INTR);
  assign lock_resume_fire = (state == LOCK_INTR) && lock_if.get_resume_ack();
  assign lock_restore = 1'b0;

  // Cleans up registers
  assign lock_refresh = state == LOCK_INIT;

  // State Machine
  always_ff @(posedge i_clk or posedge i_rst) begin
    if (i_rst) begin
      state <= LOCK_IDLE;
    end
    else begin
      state <= state_next;
    end
  end

  always_comb begin
    state_next = state;
    case (state)
      LOCK_IDLE: if (lock_trig_fire) state_next = LOCK_WAIT_GRANT;
      LOCK_WAIT_GRANT: if (txn_if.session_grant) state_next = LOCK_INIT;
      LOCK_INIT: state_next = LOCK_ACTIVE;
      LOCK_ACTIVE: if (lock_intr_fire) state_next = LOCK_INTR;
      LOCK_INTR: if (lock_resume_fire) state_next = lock_restore ? LOCK_ACTIVE : LOCK_IDLE;
      default: state_next = LOCK_IDLE;
    endcase
  end

  assign lock_if.mon_state = state;
  /*assign lock_if.done_val  = 1'b0;  // Not used in this implementation*/
  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // LOCK_ACTIVE - Ring Tuning
  // ----------------------------------------------------------------------
  always_ff @(posedge i_clk or posedge i_rst) begin
    if (i_rst) begin
      ring_tune <= '0;
    end
    else if (lock_refresh) begin
      ring_tune <= i_cfg_ring_tune_start;
    end
    else if (lock_active_update) begin
      ring_tune <= ring_tune_next;
    end
  end
  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // LOCK_ACTIVE - Controller Arbiter I/F
  // ----------------------------------------------------------------------
  assign is_session_active_state = (state == LOCK_INIT) || (state == LOCK_ACTIVE);
  assign is_ctrl_active_state = (state == LOCK_ACTIVE);
  assign lock_active_update = txn_if.fire();
  assign txn_if.val = is_ctrl_active_state;
  assign txn_if.session_req = (state == LOCK_WAIT_GRANT);
  assign txn_if.session_active = is_session_active_state;
  assign txn_if.tune_code = ring_tune;
  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // LOCK_ACTIVE - Ring Tuning
  // ----------------------------------------------------------------------
  always_ff @(posedge i_clk or posedge i_rst) begin
    if (i_rst) begin
      ring_tune_base  <= '0;
      ring_tune_delta <= '0;
    end
    else if (lock_refresh) begin
      ring_tune_base  <= i_cfg_ring_tune_start;
      ring_tune_delta <= '0;
    end
    else if (lock_active_update) begin
      ring_tune_base  <= ring_tune_base_next;
      ring_tune_delta <= ring_tune_delta_next;
    end
  end

  // Decide the next ring tune code based on the current detection
  always_comb begin
    ring_tune_base_next  = ring_tune_base;
    ring_tune_delta_next = ring_tune_delta;
    case (lock_track_state)
      TRACK_DELTA: begin
        // Generate ramp
        ring_tune_delta_next = ring_tune_delta + ring_tune_step;
      end
      TRACK_DETECT: begin
        // Update the track code based on the slope detection
        // Need to make a decision on the next ring_tune_base
        ring_tune_base_next  = ring_tune_base_decided;
        ring_tune_delta_next = '0;  // Reset ramp after update
      end
    endcase
  end

  assign ring_tune_next = ring_tune_base + ring_tune_delta;
  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // LOCK_ACTIVE - Slope Detection *TRACK_DELTA*
  // ----------------------------------------------------------------------
  // TODO: pretty much overlapping with Search PHY internal -- refactor?
  assign lock_delta_update = lock_active_update && (lock_track_state == TRACK_DELTA);

  always_ff @(posedge i_clk or posedge i_rst) begin
    if (i_rst) begin
      ring_tune_track_win[0] <= '0;
      pwr_det_track_win[0]   <= '0;
      pwr_inc_track_win[0]   <= '0;
      pwr_dec_track_win[0]   <= '0;
    end
    // Initialize the first window entry at lock_init
    else if (lock_refresh) begin
      ring_tune_track_win[0] <= '0;
      pwr_det_track_win[0]   <= '0;  // Initialize power detected track
      pwr_inc_track_win[0]   <= '0;
      pwr_dec_track_win[0]   <= '0;
    end
    else if (lock_delta_update) begin
      ring_tune_track_win[0] <= ring_tune;
      pwr_det_track_win[0]   <= txn_if.meas_power;

      if (delta_cnt != 0) begin  // drop the very first, which is invalid comparison
        pwr_inc_track_win[0] <= (txn_if.meas_power > pwr_det_track_win[0]) ? 1'b1 : 1'b0;
        pwr_dec_track_win[0] <= (txn_if.meas_power < pwr_det_track_win[0]) ? 1'b1 : 1'b0;
      end
    end
  end

  generate
    for (genvar j = 1; j < LOCK_DELTA_WINDOW_SIZE; j++) begin
      always_ff @(posedge i_clk or posedge i_rst) begin
        if (i_rst) begin
          ring_tune_track_win[j] <= '0;
          pwr_det_track_win[j]   <= '0;
          pwr_inc_track_win[j]   <= '0;
          pwr_dec_track_win[j]   <= '0;
        end
        // Initialize the first window entry at lock_init
        else if (lock_refresh) begin
          ring_tune_track_win[j] <= '0;
          pwr_det_track_win[j]   <= '0;  // Initialize power detected track
          pwr_inc_track_win[j]   <= '0;
          pwr_dec_track_win[j]   <= '0;
        end
        else if (lock_delta_update) begin
          ring_tune_track_win[j] <= ring_tune_track_win[j-1];
          pwr_det_track_win[j]   <= pwr_det_track_win[j-1];
          pwr_inc_track_win[j]   <= pwr_inc_track_win[j-1];
          pwr_dec_track_win[j]   <= pwr_dec_track_win[j-1];
        end
      end
    end
  endgenerate

  always_ff @(posedge i_clk or posedge i_rst) begin
    if (i_rst) begin
      lock_track_state <= TRACK_DELTA;
      delta_cnt <= '0;
    end
    else if (lock_refresh) begin
      lock_track_state <= TRACK_DELTA;
      delta_cnt <= '0;  // Reset delta counter on refresh
    end
    else if (lock_active_update) begin
      lock_track_state <= lock_track_state_next;
      // Increment delta counter only in TRACK_DELTA state
      if (lock_track_state == TRACK_DELTA) begin
        delta_cnt <= delta_cnt + 1;
      end
      else begin
        delta_cnt <= '0;
      end
    end
  end

  // Ramp counter and state transition
  always_comb begin
    lock_track_state_next = lock_track_state;
    case (lock_track_state)
      // If delta window is full, then move to TRACK_DETECT
      TRACK_DELTA: if (delta_cnt >= LOCK_DELTA_WINDOW_SIZE) lock_track_state_next = TRACK_DETECT;
      TRACK_DETECT: lock_track_state_next = TRACK_DELTA;
      default: lock_track_state_next = TRACK_DELTA;  // Reset to default state on error
    endcase
  end

  // Detect the slope and decide the ring_tune_base_next
  // Determine combinationally, so that it does not incur extra latency and
  // thus can be determined immediately after TRACK_DETECT state is entered
  assign pwr_incremented_vote = majority_vote(pwr_inc_track_win, lock_pwr_delta_thres_eff);
  assign pwr_decremented_vote = majority_vote(pwr_dec_track_win, lock_pwr_delta_thres_eff);

  // If power incremented, can move further to RED, if decremented, then move to BLUE
  // If both are false, it is stable, so stay at the current ring_tune_base
  always_comb begin
    ring_tune_base_decided = ring_tune_base;
    case ({
      pwr_incremented_vote, pwr_decremented_vote
    })
      2'b00: ring_tune_base_decided = ring_tune_base + ring_tune_step;  // No change
      2'b01:
      // Power decreased, move to BLUE side
      ring_tune_base_decided = ring_tune_base - ring_tune_step;
      2'b10:
      // Power increased, move to RED side
      ring_tune_base_decided = ring_tune_base + ring_tune_step;
      2'b11:
      // For now, ignore the case where both are true
      // This could be an error condition
      ring_tune_base_decided = ring_tune_base;
    endcase
  end
  // ----------------------------------------------------------------------

  function automatic logic majority_vote(input logic [LOCK_DELTA_WINDOW_SIZE-1:0] votes,
                                         input logic [LockDeltaThresWidth-1:0] threshold);
    return $countones(votes) >= threshold;
  endfunction


  // TODO: implement - skip for now
  // ----------------------------------------------------------------------
  // LOCK_ACTIVE - Simple BB Tracker
  // ----------------------------------------------------------------------
  // Compare with power level, if lower than target, then increase the heat code,
  // if higher than target, then decrease the heat code

  // ----------------------------------------------------------------------


endmodule

`default_nettype wire
