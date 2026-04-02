#include "Vdut.h"
#include "testbench/verilator_tb.hpp"
#include "utils/sweep.hpp"

#include <algorithm>
#include <csv2/writer.hpp>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

namespace {

#ifndef STRESS_DAC_WIDTH
#define STRESS_DAC_WIDTH 10
#endif

#ifndef STRESS_ADC_WIDTH
#define STRESS_ADC_WIDTH STRESS_DAC_WIDTH
#endif

constexpr int kSearchIdle = 0;
constexpr int kSearchInit = 1;
constexpr int kSearchActive = 2;
constexpr int kSearchDone = 3;
constexpr int kSearchWaitGrant = 6;

constexpr int kLockIdle = 0;
constexpr int kLockInit = 1;
constexpr int kLockActive = 2;
constexpr int kLockIntr = 3;
constexpr int kLockWaitGrant = 4;

constexpr int kLockTuneStride = 1;
constexpr int kLockPwrDeltaThres = 2;
constexpr int kSyncCycle = 4;
constexpr int kDacWidth = STRESS_DAC_WIDTH;
constexpr int kAdcWidth = STRESS_ADC_WIDTH;
constexpr int kCodeScaleShift = (kDacWidth > 8) ? (kDacWidth - 8) : 0;
constexpr int kCodeScale = 1 << kCodeScaleShift;
constexpr int kMaxTuneCode = (1 << kDacWidth) - 1;
constexpr int kFullSearchStride = (kDacWidth > 6) ? (kDacWidth - 6) : 0;

class SearchLockStressMonitor {
public:
  struct Record {
    double time;
    int tune_code;
    double i_pwr;
    double o_pwr_thru;
    double o_pwr_drop;
    int search_state;
    int lock_state;
    std::string phase;
  };

  SearchLockStressMonitor(Vdut *dut, int sample_interval)
      : dut_(dut), sample_interval_(sample_interval) {}

  void sample(vluint64_t time_ps, const std::string &phase, bool force,
              bool print) {
    const bool do_sample = force || ((interval_count_ % sample_interval_) == 0);

    if (do_sample) {
      Record record{static_cast<double>(time_ps),
                    dut_->o_ring_tune,
                    dut_->i_pwr,
                    dut_->o_pwr_thru,
                    dut_->o_pwr_drop,
                    dut_->o_search_state,
                    dut_->o_lock_state,
                    phase};
      records_.push_back(record);

      if (print) {
        std::cout << "[" << record.time << " ps] "
                  << "phase=" << record.phase
                  << " Search State=" << search_state_string(record.search_state)
                  << " Lock State=" << lock_state_string(record.lock_state)
                  << " tune=" << record.tune_code
                  << " i_pwr=" << record.i_pwr
                  << " o_pwr_thru=" << record.o_pwr_thru
                  << " o_pwr_drop=" << record.o_pwr_drop << "\n";
      }

      if (force) {
        interval_count_ = 0;
      }
    }

    ++interval_count_;
  }

  void write_csv(const std::string &filename) const {
    std::ofstream ofs(filename);
    csv2::Writer<csv2::delimiter<','>> writer(ofs);

    writer.write_row(csv_row_t{"time", "phase", "tune_code", "i_pwr",
                               "o_pwr_thru", "o_pwr_drop", "search_state",
                               "lock_state"});
    for (const auto &record : records_) {
      writer.write_row(csv_row_t{
          std::to_string(record.time),
          record.phase,
          std::to_string(record.tune_code),
          std::to_string(record.i_pwr),
          std::to_string(record.o_pwr_thru),
          std::to_string(record.o_pwr_drop),
          search_state_string(record.search_state),
          lock_state_string(record.lock_state),
      });
    }
  }

private:
  static std::string search_state_string(int state) {
    switch (state) {
    case kSearchIdle:
      return "IDLE";
    case kSearchInit:
      return "INIT";
    case kSearchActive:
      return "ACTIVE";
    case kSearchDone:
      return "DONE";
    case kSearchWaitGrant:
      return "WAIT_GRANT";
    default:
      return "UNKNOWN";
    }
  }

  static std::string lock_state_string(int state) {
    switch (state) {
    case kLockIdle:
      return "IDLE";
    case kLockInit:
      return "INIT";
    case kLockActive:
      return "ACTIVE";
    case kLockIntr:
      return "INTR";
    case kLockWaitGrant:
      return "WAIT_GRANT";
    default:
      return "UNKNOWN";
    }
  }

  Vdut *dut_;
  int sample_interval_;
  int interval_count_ = 0;
  std::vector<Record> records_;
};

[[noreturn]] void fail(const std::string &message) {
  throw std::runtime_error(message);
}

void expect(bool condition, const std::string &message) {
  if (!condition) {
    fail(message);
  }
}

} // namespace

int main(int argc, char **argv) {
  try {
    VerilatorTb<Vdut> tb(argc, argv);
    auto *dut = tb.dut();
    SearchLockStressMonitor monitor(dut, 8);
    std::string phase = "init";

    auto sample_force = [&]() {
      monitor.sample(tb.time_ps(), phase, true, true);
    };

    auto advance_clk = [&]() {
      const auto search_state_prev = dut->o_search_state;
      const auto lock_state_prev = dut->o_lock_state;
      const auto tune_prev = dut->o_ring_tune;
      tb.step_clk(dut->i_clk);
      const bool force_sample =
          (dut->o_search_state != search_state_prev) ||
          (dut->o_lock_state != lock_state_prev) ||
          (dut->o_ring_tune != tune_prev);
      monitor.sample(tb.time_ps(), phase, force_sample, force_sample);
    };

    auto advance_cycles = [&](int cycles) {
      for (int cycle = 0; cycle < cycles; ++cycle) {
        advance_clk();
      }
    };

    auto wait_until = [&](const std::string &label, int max_cycles,
                          auto predicate) {
      for (int cycle = 0; cycle < max_cycles; ++cycle) {
        if (predicate()) {
          return;
        }
        advance_clk();
      }
      fail("Timeout waiting for " + label);
    };

    auto clamp_code = [](int code) {
      return std::clamp(code, 0, kMaxTuneCode);
    };

    auto scaled_code = [&](int code_8bit) {
      return clamp_code(code_8bit * kCodeScale);
    };

    auto start_search = [&](int start, int end, int stride,
                            const std::string &label) {
      phase = label;
      dut->i_cfg_ring_tune_start = clamp_code(start);
      dut->i_cfg_ring_tune_end = clamp_code(end);
      dut->i_cfg_ring_tune_stride = stride;
      expect(dut->o_search_trig_rdy, label + ": search trigger not ready");
      dut->i_search_trig_val = 1;
      advance_clk();
      dut->i_search_trig_val = 0;
    };

    auto finish_search = [&](const std::string &label) {
      wait_until(label + " done", 20000,
                 [&]() { return dut->o_search_state == kSearchDone; });
      dut->i_search_done_rdy = 1;
      advance_clk();
      const int first_peak = dut->o_pwr_peak_tune_codes[0];
      expect(first_peak > 0, label + ": first peak code not populated");
      std::cout << label << ": first peak tune code = " << first_peak
                << " (reported peaks=" << static_cast<int>(dut->o_num_peaks)
                << ")\n";
      dut->i_search_done_rdy = 0;
      return first_peak;
    };

    auto start_lock = [&](int start, const std::string &label) {
      phase = label;
      dut->i_cfg_ring_tune_start = clamp_code(start);
      expect(dut->o_lock_trig_rdy, label + ": lock trigger not ready");
      dut->i_lock_trig_val = 1;
      advance_clk();
      dut->i_lock_trig_val = 0;
      wait_until(label + " active", 2000,
                 [&]() { return dut->o_lock_state == kLockActive; });
    };

    auto interrupt_lock = [&](const std::string &label) {
      phase = label;
      dut->i_lock_intr_val = 1;
      wait_until(label + " accepted", 2000,
                 [&]() { return dut->o_lock_state == kLockIntr; });
      dut->i_lock_intr_val = 0;
    };

    auto resume_lock_to_idle = [&](const std::string &label) {
      phase = label;
      expect(dut->o_lock_state == kLockIntr,
             label + ": lock must be in INTR before resume");
      expect(dut->o_lock_resume_rdy,
             label + ": lock resume not ready in INTR");
      dut->i_lock_resume_val = 1;
      advance_clk();
      dut->i_lock_resume_val = 0;
      wait_until(label + " idle", 16,
                 [&]() { return dut->o_lock_state == kLockIdle; });
    };

    auto restart_lock = [&](int start, const std::string &resume_label,
                            const std::string &start_label) {
      resume_lock_to_idle(resume_label);
      start_lock(start, start_label);
    };

    auto verify_search_blocked_by_lock = [&](int expected_search_start,
                                             int observe_cycles,
                                             const std::string &label) {
      phase = label;
      wait_until(label + " search queued", 128,
                 [&]() { return dut->o_search_state == kSearchWaitGrant; });
      expect(dut->o_lock_state == kLockActive,
             label + ": lock must stay ACTIVE while search is queued");

      for (int cycle = 0; cycle < observe_cycles; ++cycle) {
        expect(dut->o_lock_state == kLockActive,
               label + ": lock released unexpectedly before interrupt");
        expect(dut->o_search_state == kSearchWaitGrant,
               label + ": queued search unexpectedly left WAIT_GRANT");
        expect(dut->o_ring_tune != expected_search_start,
               label + ": queued search preempted lock ownership");
        expect(dut->o_search_state != kSearchDone,
               label + ": queued search completed before lock interrupt");
        advance_clk();
      }
    };

    dut->i_pwr = 1.0;
    dut->i_wvl_ls = 1300.0;
    dut->i_wvl_ring = 1295.0;
    dut->i_search_trig_val = 0;
    dut->i_search_done_rdy = 0;
    dut->i_lock_trig_val = 0;
    dut->i_lock_intr_val = 0;
    dut->i_lock_resume_val = 0;
    dut->i_cfg_ring_pwr_peak_ratio = 8;
    dut->i_cfg_lock_tune_stride = kLockTuneStride;
    dut->i_cfg_lock_pwr_delta_thres = kLockPwrDeltaThres;
    dut->i_cfg_sync_cycle = kSyncCycle;
    dut->i_clk = 0;

    tb.reset(dut->i_clk, dut->i_rst);
    sample_force();

    std::cout << "Stress config: DAC_WIDTH=" << kDacWidth
              << " ADC_WIDTH=" << kAdcWidth
              << " full_search_stride=" << kFullSearchStride << "\n";

    start_search(0, kMaxTuneCode, kFullSearchStride, "search_full");
    const int peak0 = finish_search("search_full");

    start_lock(peak0 - scaled_code(20), "lock_session_a");
    advance_cycles(256);

    start_search(scaled_code(96), scaled_code(200), kFullSearchStride,
                 "queued_search_a");
    verify_search_blocked_by_lock(scaled_code(96), 128, "queued_search_a");
    interrupt_lock("lock_intr_a");
    const int peak1 = finish_search("queued_search_a");

    restart_lock(peak1 + scaled_code(16), "lock_resume_a", "lock_session_b");
    advance_cycles(192);

    start_search(scaled_code(88), scaled_code(208), kFullSearchStride,
                 "queued_search_b");
    verify_search_blocked_by_lock(scaled_code(88), 128, "queued_search_b");
    interrupt_lock("lock_intr_b");
    const int peak2 = finish_search("queued_search_b");

    restart_lock(peak2 - scaled_code(12), "lock_resume_b", "lock_session_c");
    advance_cycles(128);
    interrupt_lock("lock_intr_c");
    resume_lock_to_idle("lock_resume_c");

    expect(dut->o_search_state == kSearchDone || dut->o_search_state == kSearchIdle,
           "search should not be left in an unexpected state");
    expect(dut->o_lock_state == kLockIdle,
           "lock should finish the stress sequence in IDLE");

    monitor.write_csv("search_lock_stress_waveform.csv");

    std::cout << "Stress sequence complete. Peaks: " << peak0 << ", " << peak1
              << ", " << peak2 << "\n";
    return 0;
  } catch (const std::exception &error) {
    std::cerr << "tuner_search_lock_stress failed: " << error.what() << "\n";
    return 1;
  }
}
