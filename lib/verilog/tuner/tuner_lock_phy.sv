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
    parameter int LOCK_PWR_DELTA_THRES = 2
    /*parameter logic [DAC_WIDTH-1:0] DZ_SIZE = 4*/
) (
    input var logic i_clk,
    input var logic i_rst,

    // lock config
    //    // expected to set start by offsetting the peak target to red-side
    //    input var logic [DAC_WIDTH-1:0] i_cfg_ring_tune_start,
    //    // end is not used if local search is not enabled
    //    input var logic [DAC_WIDTH-1:0] i_cfg_ring_tune_end,
    //    /*input var logic [ADC_WIDTH-1:0] i_cfg_ring_pwr_peak,*/
    input var logic [3:0] i_cfg_ring_pwr_peak_ratio,

    input var logic [DAC_WIDTH-1:0] i_dig_pwr_peak,
    input var logic [DAC_WIDTH-1:0] i_dig_ring_tune_peak,

    /*input var logic i_cfg_search_en,*/

    /*// Power Detector Interface
     *tuner_pwr_detect_if.consumer pwr_detect_if,*/

    // Controller Arbiter Interface
    tuner_ctrl_arb_if.producer ctrl_arb_if,

    //    // Search Interface for local search
    //    tuner_search_if.consumer search_if,

    // Tuner Controller Interface
    //    // consumer of trigger
    //    input var logic i_dig_lock_trig_val,
    //    output logic o_dig_lock_trig_rdy,
    //
    //    // producer of lock done
    //    output logic o_dig_lock_done_val,
    //    input var logic i_dig_lock_done_rdy,
    //
    //    // consumer of track
    //    input var logic i_dig_lock_active_val,
    //    output logic o_dig_lock_active_rdy

    tuner_lock_if.consumer lock_if
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

  /*logic lock_trig_fire;
   *logic lock_search_done;*/
  /*logic lock_active_fire;*/
  logic lock_active_stop;

  logic lock_refresh;

  /*logic lock_search_error;*/

  logic is_lock_active;
  logic lock_active_update;

  // delta window counter; delta_cnt count until LOCK_DELTA_WINDOW_SIZE + 1
  logic [$clog2(LOCK_DELTA_WINDOW_SIZE):0] delta_cnt;

  logic [DAC_WIDTH-1:0] ring_tune_step;
  logic [DAC_WIDTH-1:0] ring_tune;
  logic [DAC_WIDTH-1:0] ring_tune_next;
  logic [DAC_WIDTH-1:0] ring_tune_prev;
  logic [DAC_WIDTH-1:0] ring_tune_next_bb;

  // For now, only save a single peak information
  logic [DAC_WIDTH-1:0] pwr_peak;
  logic [DAC_WIDTH-1:0] ring_tune_peak;
  logic [DAC_WIDTH-1:0] pwr_tgt;
  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // Assigns
  // ----------------------------------------------------------------------
  // FIXME: lightweight alternative
  assign ring_pwr_tgt = i_dig_ring_pwr_peak * i_dig_ring_pwr_peak_ratio / 16;
  /*assign ring_tune_step = (1 << i_dig_ring_tune_stride);*/
  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // State Machine
  // ----------------------------------------------------------------------
  assign o_dig_lock_trig_rdy = (state == LOCK_IDLE);
  assign lock_trig_fire = o_dig_lock_trig_rdy && i_dig_lock_trig_val;

  assign lock_refresh = state == LOCK_INIT;

  /*State Machine
    *LOCK_IDLE: Waiting for init trigger
    *LOCK_INIT: Initialize registers in a single cycle and routes to SEARCH/TRACK state
    *LOCK_ACTIVE: Active tracking state
    *LOCK_ERROR: Error state*/
  always_ff @(posedge i_clk or posedge i_rst) begin
    if (i_rst) begin
      state <= LOCK_IDLE;
    end
    else begin
      state <= state_next;
    end
  end

  always_comb begin
    case (state)
      LOCK_IDLE: state_next = lock_trig_fire ? LOCK_INIT : state;
      LOCK_INIT: state_next = LOCK_ACTIVE;
      /*LOCK_INIT: state_next = LOCK_SEARCH;*/
      /*LOCK_SEARCH:
       *state_next = lock_search_done ? (lock_search_error ? LOCK_ERROR : LOCK_DONE) : state;
       *LOCK_DONE: state_next = lock_active_fire ? LOCK_ACTIVE : state;*/
      /*LOCK_ACTIVE: state_next = lock_active_error ? LOCK_ERROR : state;*/
      LOCK_ACTIVE: state_next = lock_intr_fire ? LOCK_INTR : state;
      LOCK_INTR: state_next = lock_resume_fire ? (lock_restore ? LOCK_ACTIVE : LOCK_INIT) : state;
      /*LOCK_ERROR: state_next = state;*/
      default: state_next = state;
    endcase
  end
  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // Power Detector Interface
  // ----------------------------------------------------------------------
  // Simplified consumer logic
  assign is_lock_active = (state == LOCK_ACTIVE);

  assign pwr_detect_if.pwr_detect_active = is_lock_active;
  assign pwr_detect_if.pwr_detect_refresh = !is_lock_active;
  assign lock_active_update = pwr_detect_if.pwr_detect_update;
  // ----------------------------------------------------------------------

  // FIXME this should be handled at the global controller
  //  // ----------------------------------------------------------------------
  //  // LOCK_SEARCH - Hand-off Global/Local Search to Search PHY
  //  // ----------------------------------------------------------------------
  //  // trigger Search PHY at LOCK_SEARCH state and wait for the result
  //  assign search_if.trig_val = state == LOCK_SEARCH;
  //  assign search_if.peaks_rdy = state == LOCK_SEARCH;
  //
  //  // Should pass the config to the Search PHY
  //  // For now, reuse Search PHY config? TODO
  //
  //  // Flag lock init done when Search PHY is done
  //  assign lock_search_done = search_if.get_peaks_ack();
  //  assign lock_search_error = lock_search_done && (search_if.peaks_cnt == 0);
  //
  //  // when the peak search results are valid, save to the register
  //  // For now, commit the first peak FIXME
  //  always_ff @(posedge i_clk or posedge i_rst) begin
  //    if (i_rst) begin
  //      pwr_peak <= '0;
  //      ring_tune_peak <= '0;
  //    end
  //    else if (lock_refresh) begin
  //      pwr_peak <= '0;
  //      ring_tune_peak <= '0;
  //    end
  //    else begin
  //      if (lock_search_done && !lock_search_error) begin
  //        pwr_peak <= search_if.pwr_peaks[0];
  //        ring_tune_peak <= search_if.ring_tune_peaks[0];
  //      end
  //    end
  //  end
  //  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // LOCK_ACTIVE - Ring Tuning
  // ----------------------------------------------------------------------
  always_ff @(posedge i_clk or posedge i_rst) begin
    if (i_rst) begin
      ring_tune <= '0;
    end
    /*else if (lock_refresh) begin
     *  ring_tune <= i_dig_ring_tune_start;
     *  ring_tune_prev <= i_dig_ring_tune_start;  // Initialize previous tune code
     *end*/
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

  assign ctrl_arb_if.ctrl_active = is_ctrl_active_state;
  assign ctrl_arb_if.ctrl_refresh = lock_refresh;

  assign ctrl_arb_if.tune_val[CH_LOCK] = is_tune_state && tune_compute_done;

  // commit is instantaneous
  assign update_commit_done = is_update_state;
  assign ctrl_arb_if.commit_rdy[CH_LOCK] = is_update_state && update_commit_done;

  /*assign lock_active_update = is_ctrl_active_state && ctrl_arb_if.get_ctrl_commit_ack(CH_LOCK);*/
  assign lock_active_update = is_ctrl_active_state && commit_fire;
  // compute start at the next cycle after commit
  /*assign tune_compute_start = lock_active_update;*/
  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // LOCK_ACTIVE - Ring Tuning
  // ----------------------------------------------------------------------
  // Step ring tuner at pwr detect (let pwr detector to deal with analog delays)
  assign ring_tune_step = (1 << i_dig_ring_tune_stride);
  assign tune_compute = is_tune_state && !tune_compute_done;

  // Update the ring tune base and delta
  always_ff @(posedge i_clk or posedge i_rst) begin
    if (i_rst) begin
      ring_tune_base  <= '0;
      ring_tune_delta <= '0;
    end
    else if (lock_refresh) begin
      ring_tune_base  <= i_dig_ring_tune_start;
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
    case (lock_track_state)
      TRACK_DELTA: begin
        // Generate ramp
        ring_tune_delta_next = ring_tune_delta + ring_tune_step;
        ring_tune_base_next  = ring_tune_base;
      end
      TRACK_DETECT: begin
        // Update the track code based on the slope detection
        // Need to make a decision on the next ring_tune_base
        ring_tune_base_next  = ring_tune_base_decided;
        ring_tune_delta_next = '0;  // Reset ramp after update
      end
      default: begin
        ring_tune_base_next  = ring_tune_base;
        ring_tune_delta_next = ring_tune_delta;
      end
    endcase
  end

  /*assign o_dig_ring_tune = ring_tune;*/
  assign ring_tune = ring_tune_base + ring_tune_delta;
  assign ctrl_arb_if.ring_tune = ring_tune;
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
      if (lock_track_state == TRACK_DELTA) delta_cnt <= delta_cnt + 1;
      else delta_cnt <= '0;
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
    case ({
      pwr_incremented_vote, pwr_decremented_vote
    })
      2'b00: ring_tune_base_decided = ring_tune_base;  // No change
      2'b01:
      // Power decreased, move to BLUE side
      ring_tune_base_decided = ring_tune_base - ring_tune_step;
      2'b10:
      // Power increased, move to RED side
      ring_tune_base_decided = ring_tune_base + ring_tune_step;
      2'b11:
      // For now, ignore the case where both are true
      ring_tune_base_decided = ring_tune_base;
      default: begin
        ring_tune_base_decided = ring_tune_base;
      end
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

