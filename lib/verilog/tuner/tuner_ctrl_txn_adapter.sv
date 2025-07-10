//==============================================================================
// Adapter between tuner_txn_if and existing tuner_ctrl_arb_if
// Moves the micro handshaking logic into one place so controllers only
// issue a single transaction.
//==============================================================================

`timescale 1ns/1ps
`default_nettype none

module tuner_ctrl_txn_adapter #(
    parameter int DAC_WIDTH = 8,
    parameter int ADC_WIDTH = 8,
    parameter tuner_phy_pkg::tuner_ctrl_ch_e CHANNEL = tuner_phy_pkg::CH_SEARCH
) (
    input  logic i_clk,
    input  logic i_rst,
    tuner_txn_if.arb       txn_if,
    tuner_ctrl_arb_if.producer ctrl_if
);
  import tuner_phy_pkg::*;

  typedef enum logic [1:0] {IDLE, WAIT_TUNE, WAIT_COMMIT, RESP} state_e;
  state_e state, state_next;
  logic refresh_pulse;

  // State machine
  always_ff @(posedge i_clk or posedge i_rst) begin
    if (i_rst) begin
      state <= IDLE;
    end else begin
      state <= state_next;
    end
  end

  always_comb begin
    state_next = state;
    unique case (state)
      IDLE: if (txn_if.val) state_next = WAIT_TUNE;
      WAIT_TUNE: if (ctrl_if.get_ctrl_tune_ack(CHANNEL)) state_next = WAIT_COMMIT;
      WAIT_COMMIT: if (ctrl_if.get_ctrl_commit_ack(CHANNEL)) state_next = RESP;
      RESP: if (txn_if.fire()) state_next = IDLE;
    endcase
  end

  // Refresh pulse when new transaction begins
  always_ff @(posedge i_clk or posedge i_rst) begin
    if (i_rst) refresh_pulse <= 1'b0;
    else refresh_pulse <= (state == IDLE) && (state_next == WAIT_TUNE);
  end

  // Drive control arbiter interface
  assign ctrl_if.ctrl_active[CHANNEL]  = (state != IDLE);
  assign ctrl_if.ctrl_refresh[CHANNEL] = refresh_pulse;

  assign ctrl_if.ring_tune[CHANNEL] = txn_if.tune_code;
  assign ctrl_if.tune_val[CHANNEL]  = (state == WAIT_TUNE) && txn_if.val;

  assign ctrl_if.commit_rdy[CHANNEL] = (state == WAIT_COMMIT);

  // Pass measurement back on RESP state
  assign txn_if.rdy        = (state == RESP);
  assign txn_if.meas_power = ctrl_if.pwr_commit;

endmodule

`default_nettype wire
