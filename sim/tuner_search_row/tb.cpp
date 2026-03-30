#include "Vsim.h"
#include "testbench/verilator_tb.hpp"
#include "utils/sweep.hpp"
#include <array>
#include <cassert>
#include <csv2/writer.hpp>
#include <fstream>
#include <iostream>

class SearchPhyMonitor {
public:
  typedef struct {
    double time;
    int tune_code;
    double i_pwr;
    double o_pwr;
    int state_enum;
  } search_record_t;

  SearchPhyMonitor(Vsim *dut, int ring, int interval = 1)
      : dut_(dut), ring_(ring), sample_interval_(interval) {}

  void sample(vluint64_t time, bool force, bool print) {
    bool do_sample = force || ((interval_count_ % sample_interval_) == 0);

    if (do_sample) {
      search_record_t r;
      r.time = static_cast<double>(time);
      r.tune_code = dut_->o_mon_ring_tune[ring_];
      r.i_pwr = dut_->i_pwr;
      r.o_pwr = static_cast<double>(dut_->o_mon_ring_pwr[ring_]) / 256.0;
      /*r.o_pwr = dut_->o_pwr_drop;*/
      r.state_enum = dut_->o_mon_state[ring_];
      records_.push_back(r);

      if (print) {
        std::cout << "[" << r.time << " ps] "
                  << "State=" << state_string(r.state_enum)
                  << " tune=" << r.tune_code << " i_pwr=" << r.i_pwr
                  << " o_pwr=" << r.o_pwr << "\n";
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

    // Write header
    writer.write_row(csv_row_t{"time", "tune_code", "i_pwr", "o_pwr", "state"});
    for (auto &r : records_) {
      writer.write_row(
          csv_row_t{std::to_string(r.time), std::to_string(r.tune_code),
                    std::to_string(r.i_pwr), std::to_string(r.o_pwr),
                    state_string(r.state_enum)});
    }
    ofs.close();
  }

  void change_sample_interval(int new_interval) {
    if (new_interval > 0) {
      sample_interval_ = new_interval;
      interval_count_ = 0; // Reset the interval count
    } else {
      std::cerr << "Invalid sample interval: " << new_interval
                << ". Must be greater than 0." << std::endl;
    }
  }

private:
  Vsim *dut_;
  int ring_;
  int sample_interval_;
  std::vector<search_record_t> records_;
  int state_prev_ = -1;
  int interval_count_ = 0;

  static std::string state_string(int state_enum) {
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
};

int main(int argc, char **argv) {
  constexpr int kSyncCycle = 4;
  VerilatorTb<Vsim> tb(argc, argv);
  auto *dut = tb.dut();

  constexpr size_t kNumRings = 2;
  std::array<SearchPhyMonitor, kNumRings> search_monitor{
      SearchPhyMonitor(dut, 0, 8), SearchPhyMonitor(dut, 1, 8)};

  auto advance_clk = [&](size_t ring) {
    auto search_phy_state_prev = dut->o_mon_state[ring];
    tb.step_clk(dut->i_clk);

    auto search_phy_state = dut->o_mon_state[ring];
    bool force_sample = (dut->o_mon_search_active_update[ring] ||
                         (search_phy_state != search_phy_state_prev));
    search_monitor[ring].sample(tb.time_ps(), force_sample, true);
  };

  auto search_range_string = [&](size_t ring) {
    return "Search Range: " + std::to_string(dut->i_dig_ring_tune_start[ring]) +
           " to " + std::to_string(dut->i_dig_ring_tune_end[ring]);
  };

  auto search_routine = [&](size_t ring, int start, int end, int stride = 1,
                            bool print = true) {
    assert(end >= start &&
           "search_routine: end must be greater than or equal to start");
    dut->i_dig_ring_tune_start[ring] = start;
    dut->i_dig_ring_tune_end[ring] = end;
    dut->i_dig_ring_tune_stride[ring] = stride;

    search_monitor[ring].change_sample_interval(8);
    dut->i_dig_search_trig_val[ring] = 1;
    advance_clk(ring);
    dut->i_dig_search_trig_val[ring] = 0;

    while (!dut->o_dig_search_peaks_val[ring]) {
      advance_clk(ring);
    }

    search_monitor[ring].change_sample_interval(2);
    advance_clk(ring);
    dut->i_dig_search_peaks_rdy[ring] = 1;
    advance_clk(ring);

    if (print) {
      std::cout << "Search complete, number of peaks found: "
                << (int)dut->o_dig_ring_tune_peaks_cnt[ring] << " ("
                << search_range_string(ring) << ")" << std::endl;

      for (int i = 0; i < (int)dut->o_dig_ring_tune_peaks_cnt[ring]; i++) {
        std::cout << "Peak [" << i
                  << "]: Code: " << (int)dut->o_dig_ring_tune_peaks[ring][i]
                  << " Pwr: " << (int)dut->o_dig_pwr_detected_peaks[ring][i]
                  << std::endl;
      }
    }
  };

  // DUT initialization
  dut->i_pwr = 1000.0;
  dut->i_wvl_ls[0] = 1300.0;
  dut->i_wvl_ls[1] = 1302.0;

  const std::array<double, 2> wvl_ring = {1295.0, 1298.0};
  for (size_t i = 0; i < wvl_ring.size(); ++i) {
    dut->i_wvl_ring[i] = wvl_ring[i];
  }
  for (size_t r = 0; r < kNumRings; ++r) {
    dut->i_dig_search_trig_val[r] = 0;
    dut->i_dig_search_peaks_rdy[r] = 0;
    dut->i_cfg_sync_cycle[r] = kSyncCycle;
  }

  dut->i_clk = 0; // Clock starts low

  for (size_t ring = 0; ring < wvl_ring.size(); ++ring) {
    tb.reset(dut->i_clk, dut->i_rst);

    std::cout << "--- Running search on ring " << ring << " ---" << std::endl;
    search_routine(ring, 0, 255, 2, true);
    search_routine(ring, 140, 255, 0, true);
  }

  for (size_t r = 0; r < kNumRings; ++r) {
    search_monitor[r].write_csv("search_waveform_ring" + std::to_string(r) +
                                ".csv");
  }

  return 0;
}
