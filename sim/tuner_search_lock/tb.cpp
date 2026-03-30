#include "Vdut.h"
#include "utils/sweep.hpp"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include <csv2/writer.hpp>
#include <fstream>
#include <iostream>
#include <memory>

class SearchLockPhyMonitor {
public:
  typedef struct {
    double time;
    int tune_code;
    double i_pwr;
    double o_pwr_thru;
    double o_pwr_drop;
    int search_state_enum;
    int lock_state_enum;
  } search_lock_record_t;

  typedef std::vector<int> peak_codes_t;

  SearchLockPhyMonitor(Vdut *dut) : dut_(dut) { sample_interval_ = 1; };
  SearchLockPhyMonitor(Vdut *dut, int interval)
      : dut_(dut), sample_interval_(interval){};

  void sample(vluint64_t time, bool force, bool print) {
    bool do_sample = force || ((interval_count_ % sample_interval_) == 0);

    if (do_sample) {
      search_lock_record_t r;
      r.time = static_cast<double>(time);
      r.tune_code = dut_->o_ring_tune;
      r.i_pwr = dut_->i_pwr;
      r.o_pwr_thru = dut_->o_pwr_thru;
      r.o_pwr_drop = dut_->o_pwr_drop;
      r.search_state_enum = dut_->o_search_state;
      r.lock_state_enum = dut_->o_lock_state;
      records_.push_back(r);

      if (print) {
        std::cout << "[" << r.time << " ps] "
                  << "Search State=" << search_state_string(r.search_state_enum)
                  << " Lock State=" << lock_state_string(r.lock_state_enum)
                  << " tune=" << r.tune_code << " i_pwr=" << r.i_pwr
                  << " o_pwr_thru=" << r.o_pwr_thru
                  << " o_pwr_drop=" << r.o_pwr_drop << "\n";
      }

      if (force) {
        interval_count_ = 0;
      }
    }
    interval_count_++;
  }

  void write_csv(const std::string &filename) const {
    std::ofstream ofs(filename);
    csv2::Writer<csv2::delimiter<','>> writer(ofs);

    writer.write_row(csv_row_t{"time", "tune_code", "i_pwr", "o_pwr_thru",
                               "o_pwr_drop", "search_state", "lock_state"});
    for (auto &r : records_) {
      writer.write_row(
          csv_row_t{std::to_string(r.time), std::to_string(r.tune_code),
                    std::to_string(r.i_pwr), std::to_string(r.o_pwr_thru),
                    std::to_string(r.o_pwr_drop),
                    search_state_string(r.search_state_enum),
                    lock_state_string(r.lock_state_enum)});
    }
    ofs.close();
  }

  void change_sample_interval(int new_interval) {
    if (new_interval > 0) {
      sample_interval_ = new_interval;
      interval_count_ = 0;
    } else {
      std::cerr << "Invalid sample interval: " << new_interval
                << ". Must be greater than 0." << std::endl;
    }
  }

  void record_peak(int peak_code) { peak_codes_.push_back(peak_code); }
  int get_peak(int idx) {
    if (idx < 0 || idx >= static_cast<int>(peak_codes_.size())) {
      std::cerr << "Index out of bounds: " << idx
                << ". Peak codes size: " << peak_codes_.size() << std::endl;
      return -1; // or throw an exception
    }
    return peak_codes_[idx];
  }

private:
  Vdut *dut_;
  int sample_interval_;
  int interval_count_ = 0;
  std::vector<search_lock_record_t> records_;
  peak_codes_t peak_codes_;

  static std::string state_string(int state_enum, bool is_search) {
    if (is_search) {
      return search_state_string(state_enum);
    } else {
      return lock_state_string(state_enum);
    }
  }

  static std::string search_state_string(int state_enum) {
    switch (state_enum) {
    case 0:
      return "IDLE";
    case 1:
      return "INIT";
    case 2:
      return "ACTIVE";
    case 3:
      return "DONE";
    case 4:
      return "ERROR";
    case 5:
      return "INTR";
    default:
      return "UNKNOWN";
    }
  }

  static std::string lock_state_string(int state_enum) {
    switch (state_enum) {
    case 0:
      return "IDLE";
    case 1:
      return "INIT";
    case 2:
      return "ACTIVE";
    case 3:
      return "INTR";
    default:
      return "UNKNOWN";
    }
  }
};

int main(int argc, char **argv) {
  auto contextp = std::make_unique<VerilatedContext>();
  Verilated::traceEverOn(true);
  contextp->commandArgs(argc, argv);
  auto tfp = std::make_unique<VerilatedVcdC>();
  tfp->set_time_unit("ps");
  tfp->set_time_resolution("ps");
  const auto dut = std::make_unique<Vdut>(contextp.get());
  dut->trace(tfp.get(), 99);
  tfp->open("waveform.vcd");

  vluint64_t main_time = 0;
  const vluint64_t clk_period = 10;
  int first_peak_code = 0;

  SearchLockPhyMonitor monitor(dut.get(), 8);

  auto advance_half_clk = [&]() {
    main_time += clk_period / 2;
    dut->i_clk = !dut->i_clk;
    dut->eval();
  };

  auto advance_clk = [&]() {
    auto search_state_prev = dut->o_search_state;
    auto lock_state_prev = dut->o_lock_state;
    advance_half_clk();
    advance_half_clk();
    tfp->dump(main_time);
    bool force_sample = (dut->o_search_state != search_state_prev) ||
                        (dut->o_lock_state != lock_state_prev);
    monitor.sample(main_time, force_sample, true);
  };

  auto search_routine = [&](int start, int end, int stride = 1,
                            bool print = true) {
    dut->i_cfg_ring_tune_start = start;
    dut->i_cfg_ring_tune_end = end;
    dut->i_cfg_ring_tune_stride = stride;
    dut->i_search_trig_val = 1;
    advance_clk();
    dut->i_search_trig_val = 0;
    while (dut->o_search_state != 3 /*DONE*/) {
      advance_clk();
    }
    dut->i_search_done_rdy = 1;
    advance_clk();

    // save the first peak code
    first_peak_code = (int)dut->o_pwr_peak_tune_codes[0];
    std::cout << "First peak tune code: " << first_peak_code << "\n";
    monitor.record_peak(first_peak_code);

    dut->i_search_done_rdy = 0;
  };

  auto lock_routine = [&](bool print = true) {
    dut->i_lock_trig_val = 1;
    dut->i_cfg_ring_tune_start = monitor.get_peak(0) - 20; // offset by -20
    advance_clk();
    dut->i_lock_trig_val = 0;

    for (int i = 0; i < 1000; ++i) {
      advance_clk();
    }

    // wait for lock to become active
    while (dut->o_lock_state != 2) {
      advance_clk();
    }

    // Trigger interrupt by dropping intr_rdy
    dut->i_lock_intr_rdy = 0;
    advance_clk();
    dut->i_lock_intr_rdy = 1;

    // wait until intr state entered
    while (dut->o_lock_state != 3) {
      advance_clk();
    }

    // resume after few cycles
    for (int i = 0; i < 10; ++i) {
      advance_clk();
    }
    dut->i_lock_resume_val = 1;
    dut->i_cfg_ring_tune_start = monitor.get_peak(0) + 20; // offset by +20
    advance_clk();
    dut->i_lock_resume_val = 0;
    dut->i_lock_trig_val = 1;
    advance_clk();

    for (int i = 0; i < 1000; ++i) {
      advance_clk();
    }

    // Halt Lock
    dut->i_lock_resume_val = 1;
    dut->i_cfg_ring_tune_start = 100;
    dut->i_lock_trig_val = 0;
    advance_clk();
    dut->i_lock_resume_val = 0;
    advance_clk();
  };

  dut->i_pwr = 1.0;
  dut->i_wvl_ls = 1300.0;
  dut->i_wvl_ring = 1295.0;
  dut->i_search_trig_val = 0;
  dut->i_search_done_rdy = 0;
  dut->i_lock_trig_val = 0;
  dut->i_lock_intr_rdy = 1;
  dut->i_lock_resume_val = 0;
  dut->i_cfg_ring_pwr_peak_ratio = 8;

  dut->i_clk = 0;
  dut->i_rst = 1;
  advance_clk();
  advance_clk();
  dut->i_rst = 0;
  advance_clk();

  search_routine(0, 255, 2, true);
  lock_routine(true);
  search_routine(100, 200, 2, true);

  monitor.write_csv("search_lock_waveform.csv");

  tfp->close();
  return 0;
}
