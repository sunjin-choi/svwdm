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

`define ADC_WIDTH 8
`define DAC_WIDTH 8

// TODO: implement skipping for "false positive" peaks e.g., too shallow
module tuner_search_phy #(
    parameter int NUM_TARGET = 8,
    /*parameter logic [`DAC_WIDTH-1:0] SEARCH_STEP = 8'h01,*/
    // SEARCH_STEP = 2**SEARCH_STRIDE
    parameter int SEARCH_STRIDE = 1,
    parameter int SEARCH_PEAK_WINDOW_HALFSIZE = 4,
    parameter int SEARCH_PEAK_THRES = 2
) (
    input var logic i_clk,
    input var logic i_rst,

    // search config
    input var logic [`DAC_WIDTH-1:0] i_dig_ring_tune_start,
    input var logic [`DAC_WIDTH-1:0] i_dig_ring_tune_end,

    // Power Detector Interface
    // producer of power read trigger
    output logic o_dig_pwr_read_val,
    input var logic i_dig_pwr_read_rdy,

    // consumer of power detect
    input var logic i_dig_pwr_detect_val,
    output logic o_dig_pwr_detect_rdy,
    input logic [`ADC_WIDTH-1:0] i_dig_ring_pwr_detected,

    // Tuner AFE Interface
    output logic [`DAC_WIDTH-1:0] o_dig_ring_tune,

    // Tuner Controller Interface
    // consumer of trigger
    input var logic i_dig_search_trig_val,
    output logic o_dig_search_trig_rdy,

    // producer of search results
    output logic o_dig_search_peaks_val,
    input var logic i_dig_search_peaks_rdy,

    // peak detect signal and collected tuner codes for codes
    output logic [`DAC_WIDTH-1:0] o_dig_ring_tune_peaks[NUM_TARGET],
    output logic [$clog2(NUM_TARGET)-1:0] o_dig_ring_tune_peaks_cnt,

    // Debug Monitors
    output logic o_dig_peak_detected
);
  import tuner_phy_pkg::*;

  // ----------------------------------------------------------------------
  // Internal States and Parameters
  // ----------------------------------------------------------------------
  typedef enum logic {
    PWR_READ,
    PWR_DETECT
  } search_active_state_e;

  // First half [0:SEARCH_PEAK_WINDOW_HALFSIZE-1]
  // Second half [SEARCH_PEAK_WINDOW_HALFSIZE:2*SEARCH_PEAK_WINDOW_HALFSIZE-1]
  // Detect target at SEARCH_PEAK_WINDOW_HALFSIZE-1
  localparam int SearchPeakWindowSize = 2 * SEARCH_PEAK_WINDOW_HALFSIZE + 1;
  localparam int SearchPeakWindowHalfSize = SEARCH_PEAK_WINDOW_HALFSIZE;
  localparam int SearchPeakTargetIndex = SearchPeakWindowHalfSize - 1;

  // Due to the current peak detector implementation, codes near peak would
  // all be determined as peaks, which is erroneous
  // Plus, physically the closeby peaks are not distinguishable
  localparam int PeakInvalidWindowSize = SEARCH_PEAK_THRES * 8;
  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // Signals
  // ----------------------------------------------------------------------
  // Global state
  tuner_phy_search_state_e state, state_next;

  logic search_trig_fire;
  logic search_peaks_fire;

  logic pwr_read_fire;
  logic pwr_detect_fire;

  // Internal state within SEARCH_ACTIVE
  search_active_state_e search_active_state, search_active_state_next;

  int search_active_cnt;
  int search_active_cnt_max;
  logic search_active_update;
  logic search_active_done;

  logic [`DAC_WIDTH-1:0] ring_tune_step;
  logic [`DAC_WIDTH-1:0] ring_tune;
  /*logic [`DAC_WIDTH-1:0] ring_tune_prev;*/

  /*logic [`ADC_WIDTH-1:0] ring_pwr_detected;
   *logic [`ADC_WIDTH-1:0] ring_pwr_detected_prev;*/
  logic [`DAC_WIDTH-1:0] ring_tune_track_window[SearchPeakWindowSize];
  logic [`ADC_WIDTH-1:0] pwr_detected_track_window[SearchPeakWindowSize];
  logic [`DAC_WIDTH-1:0] ring_tune_track;
  logic [`ADC_WIDTH-1:0] pwr_detected_track;

  logic pwr_incremented;
  logic pwr_decremented;
  /*logic pwr_incremented_track_window[SearchPeakWindowSize];*/
  /*logic pwr_decremented_track_window[SearchPeakWindowSize];*/
  logic [SearchPeakWindowSize-1:0] pwr_incremented_track_window;
  logic [SearchPeakWindowSize-1:0] pwr_decremented_track_window;
  logic pwr_incremented_vote;
  logic pwr_decremented_vote;

  logic peak_found;
  logic [$clog2(PeakInvalidWindowSize)-1:0] peak_invalid_cnt;
  logic peak_invalid;
  logic peak_commit;

  logic [`DAC_WIDTH-1:0] ring_tune_at_peak;
  logic [`DAC_WIDTH-1:0] ring_tune_peaks[NUM_TARGET];
  logic [$clog2(NUM_TARGET)-1:0] peak_ptr;

  logic [`ADC_WIDTH-1:0] pwr_at_peak;
  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // State Machine
  // ----------------------------------------------------------------------
  assign o_dig_search_trig_rdy = (state == SEARCH_IDLE) || (state == SEARCH_DONE);
  assign o_dig_search_peaks_val = (state == SEARCH_DONE);

  assign search_trig_fire = o_dig_search_trig_rdy && i_dig_search_trig_val;
  assign search_peaks_fire = o_dig_search_peaks_val && i_dig_search_peaks_rdy;

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
      SEARCH_IDLE: state_next = search_trig_fire ? SEARCH_ACTIVE : state;
      // If search is done, go to SEARCH_DONE
      // If search is not done, stay at SEARCH_ACTIVE
      SEARCH_ACTIVE: state_next = search_active_done ? SEARCH_DONE : state;
      // Stay at SEARCH_DONE until search_trig_fire
      SEARCH_DONE: state_next = search_trig_fire ? SEARCH_ACTIVE : state;
      SEARCH_ERROR: state_next = state;
      default: state_next = state;
    endcase
  end
  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // SEARCH_ACTIVE - Power Read/Detect Logic
  // ----------------------------------------------------------------------
  assign o_dig_pwr_read_val = (state == SEARCH_ACTIVE) && (search_active_state == PWR_READ);
  assign o_dig_pwr_detect_rdy = (state == SEARCH_ACTIVE) && (search_active_state == PWR_DETECT);

  assign pwr_read_fire = i_dig_pwr_read_rdy && o_dig_pwr_read_val;
  assign pwr_detect_fire = i_dig_pwr_detect_val && o_dig_pwr_detect_rdy;

  // Internal Read <-> Detect state logic
  always_ff @(posedge i_clk or posedge i_rst) begin
    // Default state at PWR_READ
    if (i_rst) begin
      search_active_state <= PWR_READ;
    end
    else begin
      search_active_state <= search_active_state_next;
    end
  end

  // Advance states only at SEARCH_ACTIVE
  // Each sub-state is responsible for triggering the next state at "fire"
  always_comb begin
    search_active_state_next = search_active_state;
    if (state == SEARCH_ACTIVE) begin
      case (search_active_state)
        PWR_READ: if (pwr_read_fire) search_active_state_next = PWR_DETECT;
        PWR_DETECT: if (pwr_detect_fire) search_active_state_next = PWR_READ;
        default: search_active_state_next = PWR_READ;  // Reset to PWR_READ on error
      endcase
    end
  end

  // All update logics at SEARCH_ACTIVE are triggered at pwr_detect_fire
  assign search_active_update = (state == SEARCH_ACTIVE) && pwr_detect_fire;
  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // SEARCH_ACTIVE - Count
  // ----------------------------------------------------------------------
  // Count the number of power detections taken during SEARCH_ACTIVE
  assign search_active_cnt_max = (i_dig_ring_tune_end - i_dig_ring_tune_start) >> SEARCH_STRIDE;
  assign search_active_done = (search_active_cnt >= search_active_cnt_max);

  always_ff @(posedge i_clk or posedge i_rst) begin
    if (i_rst) begin
      search_active_cnt <= 0;
    end
    else if (search_active_update) begin
      search_active_cnt <= search_active_cnt + 1;
    end
    else if (search_active_done) begin
      search_active_cnt <= 0;  // Reset count on done
    end
  end
  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // SEARCH_ACTIVE - Ring Tuning
  // ----------------------------------------------------------------------
  // Step ring tuner at pwr detect (let pwr detector to deal with analog delays)
  assign ring_tune_step = (1 << SEARCH_STRIDE);

  always_ff @(posedge i_clk or posedge i_rst) begin
    if (i_rst) begin
      ring_tune <= '0;
      /*ring_tune_prev <= '0;*/
    end
    else if (search_active_update) begin
      ring_tune <= ring_tune + ring_tune_step;
      /*ring_tune_prev <= ring_tune;*/
    end
  end

  assign o_dig_ring_tune = ring_tune;
  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // SEARCH_ACTIVE - Peak Detector
  // ----------------------------------------------------------------------
  // Majority-Vote
  /*assign pwr_incremented = (i_dig_pwr_detected > pwr_detected_track_window[0]);*/
  /*assign pwr_decremented = (i_dig_pwr_detected < pwr_detected_track_window[0]);*/
  assign pwr_incremented = pwr_detected_track_window[0] < pwr_detected_track_window[1];
  assign pwr_decremented = pwr_detected_track_window[0] > pwr_detected_track_window[1];

  always_ff @(posedge i_clk or posedge i_rst) begin
    if (i_rst) begin
      ring_tune_track_window[0] <= '0;
      pwr_detected_track_window[0] <= '0;
      pwr_incremented_track_window[0] <= '0;
      pwr_decremented_track_window[0] <= '0;
    end
    else if (search_active_update) begin
      ring_tune_track_window[0] <= ring_tune;  // Store the current tune value
      pwr_detected_track_window[0] <= i_dig_ring_pwr_detected;  // Store the current power
      pwr_incremented_track_window[0] <= pwr_incremented;
      pwr_decremented_track_window[0] <= pwr_decremented;
    end
  end

  generate
    for (genvar j = 1; j < SearchPeakWindowSize; j++) begin
      always_ff @(posedge i_clk or posedge i_rst) begin
        if (i_rst) begin
          ring_tune_track_window[j] <= '0;
          pwr_detected_track_window[j] <= '0;
          pwr_incremented_track_window[j] <= '0;
          pwr_decremented_track_window[j] <= '0;
        end
        else if (search_active_update) begin
          ring_tune_track_window[j] <= ring_tune_track_window[j-1];
          pwr_detected_track_window[j] <= pwr_detected_track_window[j-1];
          pwr_incremented_track_window[j] <= pwr_incremented_track_window[j-1];
          pwr_decremented_track_window[j] <= pwr_decremented_track_window[j-1];
        end
      end
    end
  endgenerate

  assign ring_tune_track = ring_tune_track_window[SearchPeakTargetIndex];
  assign pwr_detected_track = pwr_detected_track_window[SearchPeakTargetIndex];
  assign pwr_incremented_vote = majority_vote(
      pwr_incremented_track_window[SearchPeakWindowHalfSize-1:0], SEARCH_PEAK_THRES
  );
  assign pwr_decremented_vote = majority_vote(
      pwr_decremented_track_window[SearchPeakWindowSize:SearchPeakWindowHalfSize+1],
      SEARCH_PEAK_THRES
  );
  assign peak_found = pwr_incremented_vote && pwr_decremented_vote;

  // Peak invalidation logic
  assign peak_invalid = peak_invalid_cnt > 0;
  always_ff @(posedge i_clk or posedge i_rst) begin
    if (i_rst) begin
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
      ring_tune_at_peak <= '0;
      pwr_at_peak <= '0;

      ring_tune_peaks <= '{default: '0};
      peak_ptr <= '0;
    end
    else if (search_active_update & peak_commit) begin
      // Commit the peak
      ring_tune_at_peak <= ring_tune_track;
      pwr_at_peak <= pwr_detected_track;

      // Store the peak in the array
      ring_tune_peaks[peak_ptr] <= ring_tune_track;
      peak_ptr <= peak_ptr + 1;
    end
  end

  // Monitor
  assign o_dig_peak_detected = peak_commit;
  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // SEARCH_DONE
  // ----------------------------------------------------------------------
  /*// Commit the peak results
   *always_ff @(posedge i_clk or posedge i_rst) begin
   *  if (i_rst) begin
   *    o_dig_ring_tune_peaks <= '{default: '0};
   *    o_dig_ring_tune_peaks_cnt <= '0;
   *  end
   *  else if (state == SEARCH_DONE) begin
   *    o_dig_ring_tune_peaks <= ring_tune_peaks;
   *    o_dig_ring_tune_peaks_cnt <= peak_ptr;
   *  end
   *end*/
  // Output the search results at the same cycle as valid
  assign o_dig_ring_tune_peaks = search_peaks_fire ? ring_tune_peaks : '{default: '0};
  assign o_dig_ring_tune_peaks_cnt = search_peaks_fire ? peak_ptr : '0;
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

endmodule

`default_nettype wire

