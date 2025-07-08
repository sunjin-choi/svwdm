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
    parameter int LOCK_DELTA_WINDOW_SIZE = 4,
    parameter int LOCK_PWR_DELTA_THRES = 2,
    parameter int LOCK_TUNE_STRIDE = 0
    /*parameter logic [DAC_WIDTH-1:0] DZ_SIZE = 4*/
) (
    input var logic i_clk,
    input var logic i_rst,

    // lock config
    //    // expected to set start by offsetting the peak target to red-side
    input var logic [DAC_WIDTH-1:0] i_cfg_ring_tune_start,
    //    // end is not used if local search is not enabled
    //    input var logic [DAC_WIDTH-1:0] i_cfg_ring_tune_end,
    //    /*input var logic [ADC_WIDTH-1:0] i_cfg_ring_pwr_peak,*/
    input var logic [3:0] i_cfg_ring_pwr_peak_ratio,

    input var logic [ADC_WIDTH-1:0] i_dig_pwr_peak,
    input var logic [DAC_WIDTH-1:0] i_dig_ring_tune_peak,

    /*input var logic i_cfg_search_en,*/

    // Controller Arbiter Interface
    tuner_ctrl_arb_if.producer ctrl_arb_if,

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
  // Active during the LOCK_ACTIVE state
  /*typedef tuner_phy_ctrl_arb_if_state_e lock_active_state_e;*/
  typedef tuner_phy_ctrl_arb_if_state_e lock_active_state_e;

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
  lock_active_state_e lock_active_state, lock_active_state_next;

  lock_track_state_e lock_track_state, lock_track_state_next;

  logic lock_trig_fire;
  logic lock_intr_fire;
  logic lock_resume_fire;
  logic lock_restore;

  logic lock_refresh;

  logic is_lock_active;
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

  logic is_ctrl_active_state, is_update_state, is_tune_state;
  logic tune_fire, commit_fire;
  logic tune_compute, tune_compute_done, update_commit_done;
  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // Assigns
  // ----------------------------------------------------------------------
  /*assign pwr_tgt = i_dig_pwr_peak * i_cfg_ring_pwr_peak_ratio / 16;*/
  assign ring_tune_step = (1 << LOCK_TUNE_STRIDE);
  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // State Machine
  // ----------------------------------------------------------------------
  assign lock_if.trig_rdy = (state == LOCK_IDLE);
  assign lock_trig_fire = lock_if.get_trig_ack();

  // FIXME: track handshake should be removed -- this is weird logic
  // Interrupt is triggered by controller pulling track_rdy low
  assign lock_intr_fire = (state == LOCK_ACTIVE) && !lock_if.track_rdy;
  // Resume is triggered by controller pulling track_rdy or trig_val high
  assign lock_resume_fire = (state == LOCK_INTR) && (lock_if.track_rdy || lock_if.trig_val);
  // Restore to active state only if track_rdy is high and trig_val is low
  assign lock_restore = lock_if.track_rdy && !lock_if.trig_val;

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

  // TODO: implement lock_intr_fire and lock_resume_fire with the
  // corresponding handshake (intr/resume) signals
  always_comb begin
    state_next = state;
    case (state)
      LOCK_IDLE: if (lock_trig_fire) state_next = LOCK_INIT;
      LOCK_INIT: state_next = LOCK_ACTIVE;
      LOCK_ACTIVE: if (lock_intr_fire) state_next = LOCK_INTR;
      LOCK_INTR: if (lock_resume_fire) state_next = lock_restore ? LOCK_ACTIVE : LOCK_INIT;
      default: state_next = LOCK_IDLE;
    endcase
  end

  assign lock_if.mon_state = state;
  // FIXME: track handshake should be removed -- this is weird logic
  assign lock_if.track_rdy = (state == LOCK_ACTIVE);
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
  // Super-state for active control
  assign is_ctrl_active_state = (state == LOCK_ACTIVE);
  // Update sub-state: receive committed ring tune and power
  assign is_update_state = is_ctrl_active_state && (lock_active_state == CTRL_UPDATE);
  // Tune sub-state: compute tuner code
  assign is_tune_state = is_ctrl_active_state && (lock_active_state == CTRL_TUNE);

  assign tune_fire = ctrl_arb_if.get_ctrl_tune_ack(CH_LOCK);
  assign commit_fire = ctrl_arb_if.get_ctrl_commit_ack(CH_LOCK);

  // All update logics at LOCK_ACTIVE are triggered at commit_fire
  assign lock_active_update = is_ctrl_active_state && commit_fire;

  // Internal state for controller arbiter
  always_ff @(posedge i_clk or posedge i_rst) begin
    if (i_rst) begin
      lock_active_state <= CTRL_TUNE;  // Start with CTRL_TUNE
    end
    else if (lock_refresh) begin
      lock_active_state <= CTRL_TUNE;  // Reset to CTRL_TUNE on refresh
    end
    else begin
      lock_active_state <= lock_active_state_next;
    end
  end

  // Advance states only at LOCK_ACTIVE
  always_comb begin
    lock_active_state_next = lock_active_state;
    if (is_ctrl_active_state) begin
      case (lock_active_state)
        CTRL_TUNE: if (tune_fire) lock_active_state_next = CTRL_UPDATE;
        CTRL_UPDATE: if (commit_fire) lock_active_state_next = CTRL_TUNE;
        default: lock_active_state_next = CTRL_UPDATE;  // Reset to CTRL_TUNE on error
      endcase
    end
  end

  /*assign ctrl_arb_if.ctrl_active = is_ctrl_active_state;
   *assign ctrl_arb_if.ctrl_refresh = lock_refresh;*/
  assign ctrl_arb_if.ctrl_active[CH_LOCK] = is_ctrl_active_state;
  assign ctrl_arb_if.ctrl_refresh[CH_LOCK] = lock_refresh;

  assign ctrl_arb_if.tune_val[CH_LOCK] = is_tune_state && tune_compute_done;

  // commit is instantaneous
  assign update_commit_done = is_update_state;
  assign ctrl_arb_if.commit_rdy[CH_LOCK] = is_update_state && update_commit_done;
  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // LOCK_ACTIVE - Ring Tuning
  // ----------------------------------------------------------------------
  // Step ring tuner at pwr detect (let pwr detector to deal with analog delays)
  assign tune_compute = is_tune_state && !tune_compute_done;

  // Update the ring tune base and delta
  always_ff @(posedge i_clk or posedge i_rst) begin
    if (i_rst) begin
      ring_tune_base  <= '0;
      ring_tune_delta <= '0;
    end
    else if (lock_refresh) begin
      ring_tune_base  <= i_cfg_ring_tune_start;
      ring_tune_delta <= '0;
    end
    else if (tune_compute) begin
      ring_tune_base  <= ring_tune_base_next;
      ring_tune_delta <= ring_tune_delta_next;
    end
  end

  // Control tune_compute pulse
  always_ff @(posedge i_clk or posedge i_rst) begin
    if (i_rst) begin
      tune_compute_done <= 1'b0;
    end
    else if (lock_refresh) begin
      tune_compute_done <= 1'b0;
    end
    // Assume single-cycle tuner code compute (toggle done immediately)
    else if (is_tune_state) begin
      tune_compute_done <= 1'b1;
    end
    else if (is_update_state) begin
      tune_compute_done <= 1'b0;
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
  assign ctrl_arb_if.ring_tune[CH_LOCK] = ring_tune;
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
      ring_tune_track_win[0] <= ctrl_arb_if.ring_tune_commit;
      pwr_det_track_win[0]   <= ctrl_arb_if.pwr_commit;

      if (delta_cnt != 0) begin  // drop the very first, which is invalid comparison
        pwr_inc_track_win[0] <= (ctrl_arb_if.pwr_commit > pwr_det_track_win[0]) ? 1'b1 : 1'b0;
        pwr_dec_track_win[0] <= (ctrl_arb_if.pwr_commit < pwr_det_track_win[0]) ? 1'b1 : 1'b0;
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
  assign pwr_incremented_vote = majority_vote(pwr_inc_track_win, LOCK_PWR_DELTA_THRES);
  assign pwr_decremented_vote = majority_vote(pwr_dec_track_win, LOCK_PWR_DELTA_THRES);

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
                                         input int threshold);
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
