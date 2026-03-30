#include "Vsim.h"
#include "utils/sweep.hpp"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include <array>
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

  SearchLockPhyMonitor(Vsim *dut, int ring, int interval = 1)
      : dut_(dut), ring_(ring), sample_interval_(interval) {}

  void sample(vluint64_t time, bool force, bool print) {
    bool do_sample = force || ((interval_count_ % sample_interval_) == 0);

    if (do_sample) {
      search_lock_record_t r;
      r.time = static_cast<double>(time);
      r.tune_code = dut_->o_ring_tune[ring_];
      r.i_pwr = dut_->i_pwr;
      r.o_pwr_thru = dut_->o_pwr_thru;
      r.o_pwr_drop = dut_->o_pwr_drop[ring_];
      r.search_state_enum = dut_->o_search_state[ring_];
      r.lock_state_enum = dut_->o_lock_state[ring_];
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
  Vsim *dut_;
  int ring_;
  int sample_interval_;
  int interval_count_ = 0;
  std::vector<search_lock_record_t> records_;
  peak_codes_t peak_codes_;

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
  const auto dut = std::make_unique<Vsim>(contextp.get());
  dut->trace(tfp.get(), 99);
  tfp->open("waveform.vcd");

  vluint64_t main_time = 0;
  const vluint64_t clk_period = 10;

  constexpr size_t kNumRings = 2;
  std::array<SearchLockPhyMonitor, kNumRings> monitor{
      SearchLockPhyMonitor(dut.get(), 0, 8),
      SearchLockPhyMonitor(dut.get(), 1, 8)};

  auto advance_half_clk = [&]() {
    main_time += clk_period / 2;
    dut->i_clk = !dut->i_clk;
    dut->eval();
  };

  /*auto advance_clk = [&](size_t ring) {
   *  auto search_state_prev = dut->o_search_state[ring];
   *  auto lock_state_prev = dut->o_lock_state[ring];
   *  advance_half_clk();
   *  advance_half_clk();
   *  tfp->dump(main_time);
   *  bool force_sample = (dut->o_search_state[ring] != search_state_prev) ||
   *                      (dut->o_lock_state[ring] != lock_state_prev);
   *  monitor[ring].sample(main_time, force_sample, true);
   *};*/

  auto advance_clk = [&]() {
    advance_half_clk();
    advance_half_clk();
    tfp->dump(main_time);
    for (size_t ring = 0; ring < kNumRings; ++ring) {
      monitor[ring].sample(main_time, false, false);
    }
  };

  auto search_routine = [&](size_t ring, int start, int end, int stride = 1,
                            bool print = true) {
    assert(end >= start &&
           "search_routine: end must be greater than or equal to start");
    dut->i_cfg_ring_tune_start[ring] = start;
    dut->i_cfg_ring_tune_end[ring] = end;
    dut->i_cfg_ring_tune_stride[ring] = stride;
    dut->i_search_trig_val[ring] = 1;
    advance_clk();
    dut->i_search_trig_val[ring] = 0;

    /*while (dut->o_search_state[ring] != 3) {
     *  advance_clk();
     *}
     *dut->i_search_done_rdy[ring] = 1;
     *advance_clk();*/

    while (!dut->o_search_done_val[ring]) {
      advance_clk();
    }

    monitor[ring].change_sample_interval(2);
    advance_clk();
    dut->i_search_done_rdy[ring] = 1;
    advance_clk();

    // save the first peak code
    std::cout << "First peak tune code: "
              << (int)dut->o_pwr_peak_tune_codes[ring][0] << std::endl;
    std::cout << "Number of peaks: " << (int)dut->o_num_peaks[ring]
              << std::endl;
    monitor[ring].record_peak((int)dut->o_pwr_peak_tune_codes[ring][0]);

    dut->i_search_done_rdy[ring] = 0;

    if (print) {
      std::cout << "Ring " << ring
                << " search complete, peaks: " << (int)dut->o_num_peaks[ring]
                << std::endl;
      for (int i = 0; i < (int)dut->o_num_peaks[ring]; ++i) {
        std::cout << "Peak[" << i
                  << "] Code: " << (int)dut->o_pwr_peak_tune_codes[ring][i]
                  << " Pwr: " << (int)dut->o_pwr_peak_codes[ring][i]
                  << std::endl;
      }
    }
  };

  auto offset = [&](size_t ring) -> int { return (ring % 2 == 0) ? -20 : 20; };

  auto lock_routine = [&](size_t ring, bool print = true) {
    dut->i_lock_trig_val[ring] = 1;

    dut->i_cfg_ring_tune_start[ring] = monitor[ring].get_peak(0) + offset(ring);
    advance_clk();
    dut->i_lock_trig_val[ring] = 0;

    for (int i = 0; i < 10000; ++i) {
      advance_clk();
    }

    /*while (dut->o_lock_state[ring] != LOCK_ACTIVE) {*/
    while (dut->o_lock_state[ring] != 2) {
      advance_clk();
    }

    dut->i_lock_intr_rdy[ring] = 0;
    advance_clk();
    dut->i_lock_intr_rdy[ring] = 1;

    /*while (dut->o_lock_state[ring] != LOCK_INTR) {*/
    while (dut->o_lock_state[ring] != 3) {
      advance_clk();
    }

    for (int i = 0; i < 10; ++i) {
      advance_clk();
    }
    /*    dut->i_lock_resume_val[ring] = 1;
     *    dut->i_cfg_ring_tune_start[ring] =
     *        monitor[ring].get_peak(0) + 20; // offset by +20
     *    advance_clk();
     *    dut->i_lock_resume_val[ring] = 0;
     *    dut->i_lock_trig_val[ring] = 1;
     *    advance_clk();
     *
     *    for (int i = 0; i < 1000; ++i) {
     *      advance_clk();
     *    }
     *
     *    dut->i_lock_resume_val[ring] = 1;
     *    dut->i_cfg_ring_tune_start[ring] = 100;*/
    dut->i_lock_trig_val[ring] = 0;
    advance_clk();
    dut->i_lock_resume_val[ring] = 0;
    advance_clk();
  };

  /*dut->i_pwr = 1.0;*/
  /* Need to solve this problem -- 1.0 then 2nd ring fails. SV model ignores
   * small numbers */
  dut->i_pwr = 1000.0;
  dut->i_wvl_ls[0] = 1300.0;
  dut->i_wvl_ls[1] = 1302.0;

  const std::array<double, 2> wvl_ring = {1295.0, 1298.0};
  for (size_t i = 0; i < wvl_ring.size(); ++i) {
    dut->i_wvl_ring[i] = wvl_ring[i];
  }

  for (size_t r = 0; r < kNumRings; ++r) {
    dut->i_search_trig_val[r] = 0;
    dut->i_search_done_rdy[r] = 0;
    dut->i_lock_trig_val[r] = 0;
    dut->i_lock_intr_rdy[r] = 1;
    dut->i_lock_resume_val[r] = 0;
    dut->i_cfg_ring_pwr_peak_ratio[r] = 8;
  }

  dut->i_clk = 0;
  dut->i_rst = 1;
  advance_clk();
  advance_clk();
  dut->i_rst = 0;
  advance_clk();

  for (size_t ring = 0; ring < kNumRings; ++ring) {
    std::cout << "--- Ring " << ring << " ---" << std::endl;
    search_routine(ring, 0, 255, 2, false);
    /*search_routine(ring, 100, 200, 2, true);*/
  }

  for (size_t ring = 0; ring < kNumRings; ++ring) {
    std::cout << "--- Ring " << ring << " ---" << std::endl;
    lock_routine(ring, true);
    /*search_routine(ring, 100, 200, 2, true);*/
  }

  for (size_t r = 0; r < kNumRings; ++r) {
    monitor[r].write_csv("search_lock_waveform_ring" + std::to_string(r) +
                         ".csv");
  }

  tfp->close();
  return 0;
}
