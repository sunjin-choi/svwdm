#ifndef TESTBENCH_VERILATOR_TB_HPP
#define TESTBENCH_VERILATOR_TB_HPP

#include "verilated.h"
#include "verilated_vcd_c.h"

#include <memory>
#include <string>

template <typename TDut> class VerilatorTb {
public:
  explicit VerilatorTb(int argc, char **argv,
                       std::string waveform_file = "waveform.vcd",
                       vluint64_t clk_period_ps = 10)
      : context_(std::make_unique<VerilatedContext>()),
        trace_(std::make_unique<VerilatedVcdC>()),
        dut_(std::make_unique<TDut>(context_.get())),
        waveform_file_(std::move(waveform_file)),
        clk_period_ps_(clk_period_ps) {
    Verilated::traceEverOn(true);
    context_->commandArgs(argc, argv);

    trace_->set_time_unit("ps");
    trace_->set_time_resolution("ps");

    dut_->trace(trace_.get(), 99);
    trace_->open(waveform_file_.c_str());
  }

  ~VerilatorTb() {
    if (trace_) {
      trace_->close();
    }
  }

  TDut *dut() { return dut_.get(); }
  const TDut *dut() const { return dut_.get(); }

  vluint64_t time_ps() const { return time_ps_; }

  void eval() { dut_->eval(); }

  void advance_time(vluint64_t delta_ps) {
    eval();
    trace_->dump(time_ps_);
    time_ps_ += delta_ps;
    context_->timeInc(delta_ps);
  }

  template <typename TClk> void step_half_clk(TClk &clk_signal) {
    const auto half_period_ps = clk_period_ps_ / 2;
    time_ps_ += half_period_ps;
    context_->timeInc(half_period_ps);
    clk_signal = !clk_signal;
    eval();
  }

  template <typename TClk> void step_clk(TClk &clk_signal) {
    step_half_clk(clk_signal);
    step_half_clk(clk_signal);
    trace_->dump(time_ps_);
  }

  template <typename TClk, typename TRst>
  void reset(TClk &clk_signal, TRst &rst_signal, int cycles = 2,
             bool active_high = true) {
    rst_signal = active_high;
    for (int cycle = 0; cycle < cycles; ++cycle) {
      step_clk(clk_signal);
    }
    rst_signal = !active_high;
    step_clk(clk_signal);
  }

private:
  std::unique_ptr<VerilatedContext> context_;
  std::unique_ptr<VerilatedVcdC> trace_;
  std::unique_ptr<TDut> dut_;
  std::string waveform_file_;
  vluint64_t time_ps_ = 0;
  vluint64_t clk_period_ps_;
};

#endif // TESTBENCH_VERILATOR_TB_HPP
