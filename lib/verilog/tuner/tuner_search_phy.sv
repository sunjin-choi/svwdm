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

// Currently detects the peak
// TODO: support a simple threshold-based detection
// TODO: implement skipping for "false positive" peaks e.g., too shallow
// TODO: implement an unconditional *interrupt* signal/logic
// TODO: peaks -> done for ack logic, decide whether to switch to mailbox?
// TODO: peak code and pwr should be grouped as peaks struct?
module tuner_search_phy #(
    parameter int DAC_WIDTH = 8,
    parameter int ADC_WIDTH = 8,
    parameter int NUM_TARGET = 8,
    /*parameter logic [DAC_WIDTH-1:0] SEARCH_STEP = 8'h01,*/
    // SEARCH_STEP = 2**SEARCH_STRIDE
    parameter int SEARCH_PEAK_WINDOW_HALFSIZE = 4,
    parameter int SEARCH_PEAK_THRES = 2
) (
    input var logic i_clk,
    input var logic i_rst,

    // TODO: configs to be moved to interface?
    // search config
    input var logic [DAC_WIDTH-1:0] i_dig_ring_tune_start,
    input var logic [DAC_WIDTH-1:0] i_dig_ring_tune_end,
    input var logic [$clog2(DAC_WIDTH)-1:0] i_dig_ring_tune_stride,

    /*// Power Detector Interface
     *tuner_pwr_detect_if.consumer pwr_detect_if,*/

    // Tuning transaction interface
    tuner_txn_if.ctrl txn_if,

    // Search Interface for local search
    tuner_search_if.producer search_if,

    // Tuner AFE Interface
    output logic [DAC_WIDTH-1:0] o_dig_ring_tune

    // Tuner Controller Interface
    //    // consumer of trigger
    //    input var logic i_dig_search_trig_val,
    //    output logic o_dig_search_trig_rdy,
    //
    //    // producer of search results
    //    output logic o_dig_search_peaks_val,
    //    input var logic i_dig_search_peaks_rdy,
    //
    //    // peak detect signal and collected tuner codes for codes
    //    output logic [DAC_WIDTH-1:0] o_dig_ring_tune_peaks[NUM_TARGET],
    //    output logic [ADC_WIDTH-1:0] o_dig_pwr_detected_peaks[NUM_TARGET],
    //    output logic [$clog2(NUM_TARGET)-1:0] o_dig_ring_tune_peaks_cnt,
    //
    //    // Debug Monitors
    //    output logic o_mon_peak_commit,
    //    output logic o_mon_search_active_update,
    //    output logic [ADC_WIDTH-1:0] o_mon_ring_pwr,
    //    output logic [DAC_WIDTH-1:0] o_mon_ring_tune,
    //    output tuner_phy_search_state_e o_mon_state
);
  import tuner_phy_pkg::*;

  // ----------------------------------------------------------------------
  // Internal States and Parameters
  // ----------------------------------------------------------------------
  // Unsupported in SV-2005/Verilator-5.014
  /*typedef tuner_pwr_detect_if.pwr_detect_state_e search_active_state_e;*/
  /*typedef tuner_phy_detect_if_state_e search_active_state_e;*/


  // First half [0:SEARCH_PEAK_WINDOW_HALFSIZE-1]
  // Second half [SEARCH_PEAK_WINDOW_HALFSIZE:2*SEARCH_PEAK_WINDOW_HALFSIZE-1]
  // Detect target at SEARCH_PEAK_WINDOW_HALFSIZE-1
  localparam int SearchPeakWindowSize = 2 * SEARCH_PEAK_WINDOW_HALFSIZE + 1;
  localparam int SearchPeakWindowHalfSize = SEARCH_PEAK_WINDOW_HALFSIZE;
  localparam int SearchPeakTrackIndex = SearchPeakWindowHalfSize - 1;

  // Due to the current peak detector implementation, codes near peak would
  // all be determined as peaks, which is erroneous
  // Plus, physically the closeby peaks are not distinguishable
  localparam int PeakInvalidWindowSize = SEARCH_PEAK_THRES * 4;
  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // Signals
  // ----------------------------------------------------------------------
  // Global state
  tuner_phy_search_state_e state, state_next;

  logic search_trig_fire;
  logic search_peaks_fire;
  logic search_refresh;

  /*logic pwr_read_fire;*/
  /*logic pwr_detect_fire;*/
  logic txn_valid;

  int search_active_cnt;
  int search_active_cnt_max;
  logic search_active_update;
  logic search_active_done;
  logic is_ctrl_active_state;

  logic [DAC_WIDTH-1:0] ring_tune_step;
  logic [DAC_WIDTH-1:0] ring_tune;
  /*logic [DAC_WIDTH-1:0] ring_tune_prev;*/

  /*logic [ADC_WIDTH-1:0] ring_pwr_detected;
   *logic [ADC_WIDTH-1:0] ring_pwr_detected_prev;*/
  logic [DAC_WIDTH-1:0] ring_tune_track_win[SearchPeakWindowSize];
  logic [ADC_WIDTH-1:0] pwr_det_track_win[SearchPeakWindowSize];
  logic [DAC_WIDTH-1:0] ring_tune_track;
  logic [ADC_WIDTH-1:0] pwr_det_track;
  logic [DAC_WIDTH-1:0] ring_tune_peak_track;
  logic [ADC_WIDTH-1:0] pwr_peak_track;

  logic pwr_incremented;
  logic pwr_decremented;
  /*logic pwr_incremented_track_window[SearchPeakWindowSize];*/
  /*logic pwr_decremented_track_window[SearchPeakWindowSize];*/
  logic [SearchPeakWindowSize-1:0] pwr_inc_track_win;
  logic [SearchPeakWindowSize-1:0] pwr_dec_track_win;
  logic pwr_incremented_vote;
  logic pwr_decremented_vote;

  logic peak_found;
  logic [$clog2(PeakInvalidWindowSize)-1:0] peak_invalid_cnt;
  logic peak_invalid;
  logic peak_commit;

  logic [DAC_WIDTH-1:0] ring_tune_peaks[NUM_TARGET];
  logic [ADC_WIDTH-1:0] pwr_peaks[NUM_TARGET];
  logic [$clog2(NUM_TARGET)-1:0] peak_ptr;

  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // State Machine
  // ----------------------------------------------------------------------
  /*assign o_dig_search_trig_rdy = (state == SEARCH_IDLE) || (state == SEARCH_DONE);*/
  /*assign o_dig_search_peaks_val = (state == SEARCH_DONE);*/
  assign search_if.trig_rdy = (state == SEARCH_IDLE) || (state == SEARCH_DONE);
  assign search_if.peaks_val = (state == SEARCH_DONE);

  assign search_refresh = state == SEARCH_INIT;

  /*assign search_trig_fire = o_dig_search_trig_rdy && i_dig_search_trig_val;*/
  /*assign search_peaks_fire = o_dig_search_peaks_val && i_dig_search_peaks_rdy;*/
  assign search_trig_fire = search_if.get_trig_ack();
  assign search_peaks_fire = search_if.get_peaks_ack();

  // State machine
  always_ff @(posedge i_clk or posedge i_rst) begin
    if (i_rst) begin
      state <= SEARCH_IDLE;
    end
    else begin
      state <= state_next;
    end
  end

  always_comb begin
    case (state)
      /*SEARCH_IDLE: state_next = search_trig_fire ? SEARCH_ACTIVE : state;*/
      SEARCH_IDLE: state_next = search_trig_fire ? SEARCH_INIT : state;
      // this state initializes the registers in a single cycle
      SEARCH_INIT: state_next = SEARCH_ACTIVE;
      // If search is done, go to SEARCH_DONE
      // If search is not done, stay at SEARCH_ACTIVE
      SEARCH_ACTIVE: state_next = search_active_done ? SEARCH_DONE : state;
      // Stay at SEARCH_DONE until search_trig_fire
      /*SEARCH_DONE: state_next = search_trig_fire ? SEARCH_ACTIVE : state;*/
      SEARCH_DONE: state_next = search_trig_fire ? SEARCH_INIT : state;
      SEARCH_ERROR: state_next = state;
      default: state_next = state;
    endcase
  end
  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // SEARCH_ACTIVE - Power Read/Detect Logic
  // ----------------------------------------------------------------------
  //  /*assign o_dig_pwr_read_val = (state == SEARCH_ACTIVE) && (search_active_state == PWR_READ);
  //   *assign o_dig_pwr_detect_rdy = (state == SEARCH_ACTIVE) && (search_active_state == PWR_DETECT);*/
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

  /*// Refactored above handshaking logic to pwr_detect_if to simplify consumer
   *assign pwr_detect_if.pwr_detect_active = (state == SEARCH_ACTIVE);
   *assign pwr_detect_if.pwr_detect_refresh = (state == SEARCH_INIT);
   *assign search_active_update = pwr_detect_if.pwr_detect_update;*/
  // ----------------------------------------------------------------------
  // SEARCH_ACTIVE - Transaction I/F
  // ----------------------------------------------------------------------
  assign is_ctrl_active_state = (state == SEARCH_ACTIVE);
  assign search_active_update = txn_if.fire();
  assign txn_if.val = is_ctrl_active_state && txn_valid;
  assign txn_if.tune_code = ring_tune;

  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // SEARCH_ACTIVE - Ring Tuning
  // ----------------------------------------------------------------------
  assign ring_tune_step = (1 << i_dig_ring_tune_stride);

  always_ff @(posedge i_clk or posedge i_rst) begin
    if (i_rst) begin
      ring_tune <= '0;
    end else if (search_refresh) begin
      ring_tune <= i_dig_ring_tune_start;
    end else if (txn_if.fire()) begin
      ring_tune <= ring_tune + ring_tune_step;
    end
  end

  assign o_dig_ring_tune = ring_tune;

  // ----------------------------------------------------------------------
  // Count the number of power detections taken during SEARCH_ACTIVE
  assign search_active_cnt_max = (i_dig_ring_tune_end - i_dig_ring_tune_start) >> i_dig_ring_tune_stride;
  assign search_active_done = (search_active_cnt >= search_active_cnt_max);

  always_ff @(posedge i_clk or posedge i_rst) begin
    if (i_rst) begin
      search_active_cnt <= 0;
    end
    else if (search_refresh) begin
      search_active_cnt <= 0;  // Reset count on init
    end
    else if (search_active_update) begin
      search_active_cnt <= search_active_cnt + 1;
    end
  end

  always_ff @(posedge i_clk or posedge i_rst) begin
    if (i_rst) begin
      txn_valid <= 1'b0;
    end
    else if (search_refresh) begin
      txn_valid <= 1'b1;
    end
    else if (txn_if.fire()) begin
      txn_valid <= ~search_active_done;
    end
  end
  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // SEARCH_ACTIVE - Peak Detector
  // ----------------------------------------------------------------------
  // TODO: check if saving to the window directly is better, doesn't matter
  // for search?
  always_ff @(posedge i_clk or posedge i_rst) begin
    if (i_rst) begin
      pwr_det_track   <= '0;
      ring_tune_track <= '0;
    end
    else if (search_refresh) begin
      // TODO: misleading information? pwr is not 0 at the tune_start
      pwr_det_track   <= '0;  // Initialize power detected track
      ring_tune_track <= i_dig_ring_tune_start;  // Start from the initial tune code
    end
    else if (search_active_update) begin
      // Receive the committed ring tune and power from the controller arbiter
      pwr_det_track   <= txn_if.meas_power;
      ring_tune_track <= ring_tune;
  /*assign pwr_decremented = (i_dig_pwr_detected < pwr_detected_track_window[0]);*/
  assign pwr_incremented = pwr_det_track_win[0] > pwr_det_track_win[1];
  assign pwr_decremented = pwr_det_track_win[0] < pwr_det_track_win[1];

  always_ff @(posedge i_clk or posedge i_rst) begin
    if (i_rst) begin
      ring_tune_track_win[0] <= '0;
      pwr_det_track_win[0]   <= '0;
      pwr_inc_track_win[0]   <= '0;
      pwr_dec_track_win[0]   <= '0;
    end
    // Initialize the first window entry at search_init
    else if (search_refresh) begin
      ring_tune_track_win[0] <= '0;
      pwr_det_track_win[0]   <= '0;  // Initialize power detected track
      pwr_inc_track_win[0]   <= '0;
      pwr_dec_track_win[0]   <= '0;
    end
    else if (search_active_update) begin
      ring_tune_track_win[0] <= ring_tune_track;
      pwr_det_track_win[0]   <= pwr_det_track;
      pwr_inc_track_win[0]   <= pwr_incremented;
      pwr_dec_track_win[0]   <= pwr_decremented;
    end
  end

  generate
    for (genvar j = 1; j < SearchPeakWindowSize; j++) begin
      always_ff @(posedge i_clk or posedge i_rst) begin
        if (i_rst) begin
          ring_tune_track_win[j] <= '0;
          pwr_det_track_win[j]   <= '0;
          pwr_inc_track_win[j]   <= '0;
          pwr_dec_track_win[j]   <= '0;
        end
        // Initialize the first window entry at search_init
        else if (search_refresh) begin
          ring_tune_track_win[j] <= '0;
          pwr_det_track_win[j]   <= '0;  // Initialize power detected track
          pwr_inc_track_win[j]   <= '0;
          pwr_dec_track_win[j]   <= '0;
        end
        else if (search_active_update) begin
          ring_tune_track_win[j] <= ring_tune_track_win[j-1];
          pwr_det_track_win[j]   <= pwr_det_track_win[j-1];
          pwr_inc_track_win[j]   <= pwr_inc_track_win[j-1];
          pwr_dec_track_win[j]   <= pwr_dec_track_win[j-1];
        end
      end
    end
  endgenerate

  assign ring_tune_peak_track = ring_tune_track_win[SearchPeakTrackIndex];
  assign pwr_peak_track = pwr_det_track_win[SearchPeakTrackIndex];
  assign pwr_incremented_vote = majority_vote(
      pwr_inc_track_win[SearchPeakWindowSize:SearchPeakWindowHalfSize+1],
      SEARCH_PEAK_THRES
      /*pwr_incremented_track_window[SearchPeakWindowHalfSize-1:0], SEARCH_PEAK_THRES*/
  );
  assign pwr_decremented_vote = majority_vote(
      pwr_dec_track_win[SearchPeakWindowHalfSize-1:0],
      SEARCH_PEAK_THRES
      /*pwr_decremented_track_window[SearchPeakWindowSize:SearchPeakWindowHalfSize+1],
       *SEARCH_PEAK_THRES*/
  );
  assign peak_found = pwr_incremented_vote && pwr_decremented_vote;

  // Peak invalidation logic
  assign peak_invalid = peak_invalid_cnt > 0 || search_active_cnt <= SearchPeakWindowSize;
  always_ff @(posedge i_clk or posedge i_rst) begin
    if (i_rst) begin
      peak_invalid_cnt <= '0;
    end
    // Reset invalid count at search_init
    else if (search_refresh) begin
      peak_invalid_cnt <= '0;
    end
    else if (search_active_update) begin
      case ({
        peak_found, peak_invalid
      })
        2'b10: peak_invalid_cnt <= peak_invalid_cnt + 1;  // Found a peak, invalidate the next
        2'b01: peak_invalid_cnt <= peak_invalid_cnt + 1;  // Invalidated, keep invalidating
        2'b11:
        peak_invalid_cnt <= peak_invalid_cnt + 1; // Found a peak that is invalid, keep invalidating
        2'b00: peak_invalid_cnt <= '0;  // No peak found, reset invalid count
        default: peak_invalid_cnt <= peak_invalid_cnt;
      endcase
    end
  end

  // commit the peak only if it is valid
  assign peak_commit = peak_found && !peak_invalid;

  always_ff @(posedge i_clk or posedge i_rst) begin
    if (i_rst) begin
      ring_tune_peaks <= '{default: '0};
      pwr_peaks <= '{default: '0};
      peak_ptr <= '0;
    end
    // Reset the peak pointer at search_init
    else if (search_refresh) begin
      ring_tune_peaks <= '{default: '0};
      pwr_peaks <= '{default: '0};
      peak_ptr <= '0;
    end
    else if (search_active_update & peak_commit) begin
      // Store the peak in the array
      ring_tune_peaks[peak_ptr] <= ring_tune_peak_track;
      pwr_peaks[peak_ptr] <= pwr_peak_track;
      peak_ptr <= peak_ptr + 1;
    end
  end
  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // SEARCH_DONE
  // ----------------------------------------------------------------------
  // Output the search results at the same cycle as valid
  /*assign o_dig_ring_tune_peaks = search_peaks_fire ? ring_tune_peaks : '{default: '0};*/
  /*assign o_dig_pwr_peaks = search_peaks_fire ? pwr_peaks : '{default: '0};*/
  /*assign o_dig_ring_tune_peaks_cnt = search_peaks_fire ? peak_ptr : '0;*/
  assign search_if.ring_tune_peaks = search_peaks_fire ? ring_tune_peaks : '{default: '0};
  assign search_if.pwr_peaks = search_peaks_fire ? pwr_peaks : '{default: '0};
  assign search_if.peaks_cnt = search_peaks_fire ? peak_ptr : '0;
  // ----------------------------------------------------------------------

  function automatic logic majority_vote(input logic [SearchPeakWindowHalfSize-1:0] votes,
                                         input int threshold);
    /*logic [$clog2(SearchPeakWindowHalfSize)-1:0] votes_sum;*/
    int votes_sum;
    votes_sum = 0;
    for (int i = 0; i < SearchPeakWindowHalfSize; i++) begin
      votes_sum += votes[i];
    end
    return (votes_sum >= threshold);
  endfunction

  // ----------------------------------------------------------------------
  // Monitor logic
  // ----------------------------------------------------------------------
  /*assign o_mon_peak_commit = peak_commit;
   *assign o_mon_search_active_update = search_active_update;
   *assign o_mon_ring_pwr = pwr_detected_track;
   *assign o_mon_ring_tune = ring_tune_track;
   *assign o_mon_state = state;*/

  assign search_if.mon_peak_commit = peak_commit;
  assign search_if.mon_search_active_update = search_active_update;
  assign search_if.mon_ring_pwr = pwr_det_track;
  assign search_if.mon_ring_tune = ring_tune_track;
  assign search_if.mon_state = state;
  // ----------------------------------------------------------------------

endmodule

`default_nettype wire

