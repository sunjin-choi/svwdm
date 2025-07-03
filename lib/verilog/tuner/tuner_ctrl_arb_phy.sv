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

// Tuner Interface & Committer/Synchronizer a.k.a *Controller* Arbiter
// Tracker should deal with delayed synchronization btw detected pwr and tuner
// codes
module tuner_ctrl_arb_phy #(
    parameter int DAC_WIDTH  = 8,
    parameter int ADC_WIDTH  = 8,
    parameter int SYNC_CYCLE = 4
) (
    input var logic i_clk,
    input var logic i_rst,

    // Power Detector Interface
    tuner_pwr_detect_if.consumer pwr_detect_if,

    tuner_ctrl_arb_if.consumer arb_if,

    // Tuner AFE Interface
    output logic [DAC_WIDTH-1:0] o_dig_afe_ring_tune,
    input logic i_afe_ring_tune_rdy,
    output logic o_afe_ring_tune_val

    /*    input var logic i_ctrl_active,
 *    input var logic i_ctrl_refresh,
 *
 *    input logic i_ctrl_ring_tune_val,
 *    output logic o_ctrl_ring_tune_rdy,
 *    input logic [ADC_WIDTH-1:0] i_ctrl_ring_tune,
 *
 *    output logic o_ctrl_commit_val,
 *    input logic i_ctrl_commit_rdy,
 *    output logic [ADC_WIDTH-1:0] o_ctrl_pwr_commit,
 *    output logic [DAC_WIDTH-1:0] o_ctrl_ring_tune_commit*/

);

  import tuner_phy_pkg::*;
  // ----------------------------------------------------------------------
  // Internal States and Parameters
  // ----------------------------------------------------------------------
  //  // helper states (lock active/inactive)
  //  typedef enum logic {
  //    LOCK_ACTIVE   = 1'b1,
  //    LOCK_INACTIVE = 1'b0
  //  } lock_active_t;

  tuner_phy_ctrl_arb_state_e state, state_next;
  logic pwr_detect_update;
  logic [3:0] sync_cnt;
  logic sync_cnt_done;
  logic sync_cnt_update;
  logic ctrl_refresh;
  logic ctrl_sync;

  logic ctrl_ring_tune_fire;
  logic afe_tune_fire;
  logic ring_tune_fire;

  logic ctrl_commit_fire;

  logic [DAC_WIDTH-1:0] ring_tune;
  logic [DAC_WIDTH-1:0] ring_tune_track;
  logic [ADC_WIDTH-1:0] pwr_detected_commit;
  logic [DAC_WIDTH-1:0] ring_tune_commit;
  logic [ADC_WIDTH-1:0] pwr_commit;

  assign afe_tune_fire = i_afe_ring_tune_rdy && o_afe_ring_tune_val;
  /*assign ctrl_ring_tune_fire = i_ctrl_ring_tune_val && o_ctrl_ring_tune_rdy;*/
  /*assign ctrl_commit_fire = i_ctrl_commit_rdy && o_ctrl_commit_val;*/
  assign ctrl_ring_tune_fire = arb_if.get_ctrl_ring_tune_ack(CH_SEARCH);  // FIXME
  assign ctrl_commit_fire = arb_if.get_ctrl_commit_ack(CH_SEARCH);  // FIXME

  // Let high-level ctrl PHY to update the tuner code and fire
  // High-level Control (producer) -> Ctrl PHY (middle) -> Tuner (consumer)
  // Fire the tuner code *only* when both producer and consumer agree
  assign ring_tune_fire = afe_tune_fire && ctrl_ring_tune_fire;
  /*assign ctrl_tune_fire = tuner_if_arb_if.get_compute_ack();*/
  /*assign ctrl_commit_fire = tuner_if_arb_if.get_commit_ack();*/
  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // Power Detection I/F
  // ----------------------------------------------------------------------
  //  assign pwr_detect_if.read_val = (state == SEARCH_ACTIVE) && (search_active_state == PWR_READ);
  //  assign pwr_detect_if.detect_rdy = (state == SEARCH_ACTIVE) && (search_active_state == PWR_DETECT);
  //
  //  /*assign pwr_read_fire = i_dig_pwr_read_rdy && o_dig_pwr_read_val;
  //   *assign pwr_detect_fire = i_dig_pwr_detect_val && o_dig_pwr_detect_rdy;*/
  //  assign pwr_read_fire = pwr_detect_if.get_read_ack();
  //  assign pwr_detect_fire = pwr_detect_if.get_detect_ack();
  //
  //  // Internal Read <-> Detect state logic
  //  always_ff @(posedge i_clk or posedge i_rst) begin
  //    // Default state at PWR_READ
  //    if (i_rst) begin
  //      search_active_state <= PWR_READ;
  //    end
  //    // refresh at search enter (init)
  //    else if (search_refresh) begin
  //      search_active_state <= PWR_READ;
  //    end
  //    else begin
  //      search_active_state <= search_active_state_next;
  //    end
  //  end
  //
  //  // Advance states only at SEARCH_ACTIVE
  //  // Each sub-state is responsible for triggering the next state at "fire"
  //  always_comb begin
  //    search_active_state_next = search_active_state;
  //    if (state == SEARCH_ACTIVE) begin
  //      case (search_active_state)
  //        PWR_READ: if (pwr_read_fire) search_active_state_next = PWR_DETECT;
  //        PWR_DETECT: if (pwr_detect_fire) search_active_state_next = PWR_READ;
  //        default: search_active_state_next = PWR_READ;  // Reset to PWR_READ on error
  //      endcase
  //    end
  //  end
  //
  //  // All update logics at SEARCH_ACTIVE are triggered at pwr_detect_fire
  //  assign search_active_update = (state == SEARCH_ACTIVE) && pwr_detect_fire;

  // Simplified pwr detection interface
  /*assign pwr_detect_if.pwr_detect_active = (state == SEARCH_ACTIVE);
   *assign pwr_detect_if.pwr_detect_refresh = (state == SEARCH_INIT);*/

  // Power detection is always active when ctrl is active
  /*assign pwr_detect_if.pwr_detect_active = i_ctrl_active;*/
  /*assign pwr_detect_if.pwr_detect_refresh = i_ctrl_refresh;*/
  assign pwr_detect_if.pwr_detect_active = arb_if.get_pwr_detect_active();
  assign pwr_detect_if.pwr_detect_refresh = arb_if.ctrl_refresh;
  assign ctrl_refresh = arb_if.ctrl_refresh;

  assign pwr_detect_update = pwr_detect_if.pwr_detect_update;

  // Sync counter update when power detection is active
  // So that it essentially waits for the current tune code's resulting pwr
  assign sync_cnt_update = pwr_detect_update;
  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // State Machine
  // ----------------------------------------------------------------------
  always_ff @(posedge i_clk or posedge i_rst) begin
    if (i_rst) begin
      state <= ARB_CTRL_INIT;
    end
    else if (ctrl_refresh) begin
      state <= ARB_CTRL_INIT;
    end
    else begin
      state <= state_next;
    end
  end

  // TODO: write a safe-guard for sync_cnt_update i.e., if sync_cnt_update
  // spans multiple clock cycles, only increment onces
  always_ff @(posedge i_clk or posedge i_rst) begin
    if (i_rst) begin
      sync_cnt <= '0;
    end
    else begin
      case (state)
        ARB_CTRL_INIT: sync_cnt <= '0;
        ARB_CTRL_TUNE: sync_cnt <= '0;
        ARB_CTRL_SYNC: sync_cnt <= sync_cnt_update ? sync_cnt + 1 : sync_cnt;
        ARB_CTRL_COMMIT: sync_cnt <= '0;
        default: sync_cnt <= sync_cnt;  // Maintain current sync count
      endcase
    end
  end

  assign sync_cnt_done = (state == ARB_CTRL_SYNC) && (sync_cnt == SYNC_CYCLE - 1);

  always_comb begin
    case (state)
      // Begin at pwr_detect_update, move to COMMIT which is aligned with the
      // producer side (start with UPDATE)
      /*ARB_CTRL_INIT: state_next = pwr_detect_update ? ARB_CTRL_COMMIT : state;*/
      ARB_CTRL_INIT: state_next = ARB_CTRL_TUNE;
      // Advance state after firing tuner code to Tuner
      ARB_CTRL_TUNE: state_next = ring_tune_fire ? ARB_CTRL_SYNC : state;
      // Commit the control status to the higher-level logic (search/lock)
      ARB_CTRL_COMMIT: state_next = ctrl_commit_fire ? ARB_CTRL_TUNE : state;
      // Tune-to-detect sync counter
      ARB_CTRL_SYNC: state_next = sync_cnt_done ? ARB_CTRL_COMMIT : state;
      default: state_next = state;
    endcase
  end
  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // ARB_CTRL_TUNE
  // ----------------------------------------------------------------------
  // Change the tuner code at tune_fire and keep the previous one
  // Yet consumer (tuner) is also responsible of keeping the previous data,
  // duplicate the logic here for simplicity
  /*assign ring_tune = ring_tune_fire ? i_ctrl_ring_tune : ring_tune_track;*/
  assign ring_tune = ring_tune_fire ? arb_if.ring_tune : ring_tune_track;

  always_ff @(posedge i_clk or posedge i_rst) begin
    if (i_rst) begin
      ring_tune_track <= '0;
    end
    else if (ctrl_refresh) begin
      ring_tune_track <= '0;
    end
    else if (ring_tune_fire) begin
      ring_tune_track <= ring_tune;
    end
  end

  // Intercept rdy/val so that producer and consumer can decide to fire the
  // tuner code *only* when middle-level arbiter agrees
  // This is essential for implementing the synchronization logic
  /*assign o_afe_ring_tune_val = i_ctrl_ring_tune_val && (state == ARB_CTRL_TUNE);*/
  /*assign o_ctrl_ring_tune_rdy = i_afe_ring_tune_rdy && (state == ARB_CTRL_TUNE);*/
  assign o_afe_ring_tune_val = arb_if.ring_tune_val[CH_SEARCH] && (state == ARB_CTRL_TUNE); // FIXME
  assign arb_if.ring_tune_rdy = i_afe_ring_tune_rdy && (state == ARB_CTRL_TUNE);

  assign o_dig_afe_ring_tune = ring_tune;
  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // ARB_CTRL_SYNC - Synchronized Commit
  // ----------------------------------------------------------------------
  // Power detection data is naturally synchronized wrt the tuner code
  // This logic keep overwrites to the commiter registers until the ARB_CTRL_SYNC is
  // done and therefore, synchronized
  // sync_cnt_update is controlled by the pwr_detect_update signal
  // (pwr_detect_if)
  assign ctrl_sync = (state == ARB_CTRL_SYNC) && sync_cnt_update;

  always_ff @(posedge i_clk or posedge i_rst) begin
    if (i_rst) begin
      pwr_detected_commit <= '0;
      ring_tune_commit <= '0;
    end
    else if (ctrl_refresh) begin
      pwr_detected_commit <= '0;
      ring_tune_commit <= '0;
    end
    else if (ctrl_sync) begin
      pwr_detected_commit <= pwr_detect_if.detect_data;
      ring_tune_commit <= ring_tune_track;
    end
  end

  // TODO: add AFE interface as tuner so that tuner/detect AFE scan ctrl can
  // be more flexible, also turn on power detect only during sync
  // Should get back the rdy/val i/f
  // Currently cannot precisely control when it reads from AFE I/F

  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // ARB_CTRL_COMMIT
  // ----------------------------------------------------------------------
  // Commit the synchronized tuner and power values to the higher-level control
  // system. This happens once the FSM enters ARB_CTRL_COMMIT and the higher-level
  // logic asserts i_ctrl_commit_rdy.

  // Output committed values
  /*assign o_ctrl_pwr_commit       = pwr_detected_commit;*/
  /*assign o_ctrl_ring_tune_commit = ring_tune_commit;*/
  assign arb_if.pwr_commit       = pwr_detected_commit;
  assign arb_if.ring_tune_commit = ring_tune_commit;

  // Drive valid signal only in COMMIT state
  /*assign o_ctrl_commit_val       = (state == ARB_CTRL_COMMIT);*/
  assign arb_if.commit_val       = (state == ARB_CTRL_COMMIT);
  // ----------------------------------------------------------------------

endmodule

`default_nettype wire

