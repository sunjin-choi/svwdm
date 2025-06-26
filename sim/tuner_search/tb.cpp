#include "Vsim.h"
#include "utils/sweep.hpp"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include <csv2/writer.hpp>
#include <fstream>
#include <iostream>
#include <memory>

class SearchPhyMonitor {
public:
  typedef struct {
    double time;
    int tune_code;
    double i_pwr;
    double o_pwr;
    int state_enum;
  } search_record_t;

  SearchPhyMonitor(Vsim *dut) : dut_(dut) { sample_interval_ = 1; };
  SearchPhyMonitor(Vsim *dut, int interval)
      : dut_(dut), sample_interval_(interval){};

  void sample(vluint64_t time, bool force, bool print) {
    bool do_sample = force || ((interval_count_ & sample_interval_) == 0);

    if (do_sample) {
      search_record_t r;
      r.time = static_cast<double>(time);
      r.tune_code = dut_->o_mon_ring_tune;
      r.i_pwr = dut_->i_pwr;
      r.o_pwr = static_cast<double>(dut_->o_mon_ring_pwr) / 256.0;
      /*r.o_pwr = dut_->o_pwr_drop;*/
      r.state_enum = dut_->o_mon_state;
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

  // Construct a VerilatedContext to hold simulation time, etc
  /*VerilatedContext *const contextp = new VerilatedContext;*/
  auto contextp = std::make_unique<VerilatedContext>();

  Verilated::traceEverOn(true);

  // Pass arguments so Verilated code can see them, e.g. $value$plusargs
  // This needs to be called before you create any model
  contextp->commandArgs(argc, argv);

  /*VerilatedVcdC *tfp = new VerilatedVcdC;*/
  auto tfp = std::make_unique<VerilatedVcdC>();
  // Default does not work out -- manually set time unit and resolution
  tfp->set_time_unit("ps");
  tfp->set_time_resolution("ps");

  // Construct the Verilated model, from Vsim.h generated from Verilating
  /*Vsim *const dut = new Vsim{contextp};*/
  const auto dut = std::make_unique<Vsim>(contextp.get());

  dut->trace(tfp.get(), 99);
  tfp->open("waveform.vcd");

  // Time variable
  vluint64_t main_time = 0;
  const vluint64_t clk_period = 10;

  // Create a search monitor
  SearchPhyMonitor search_monitor(dut.get(), 8);

  auto advance_half_clk = [&]() {
    main_time += clk_period / 2;
    dut->i_clk = !dut->i_clk;
    dut->eval();
    /*tfp->dump(main_time);*/
  };

  auto advance_clk = [&]() {
    auto search_phy_state_prev = dut->o_mon_state;

    advance_half_clk();
    advance_half_clk();
    tfp->dump(main_time);

    auto search_phy_state = dut->o_mon_state;
    bool force_sample = (dut->o_mon_search_active_update ||
                         (search_phy_state != search_phy_state_prev));
    search_monitor.sample(main_time, force_sample, true);
  };

  auto search_range_string = [&]() {
    return "Search Range: " + std::to_string(dut->i_dig_ring_tune_start) +
           " to " + std::to_string(dut->i_dig_ring_tune_end);
  };

  auto search_routine = [&](int start, int end, int stride = 1,
                            bool print = true) {
    dut->i_dig_ring_tune_start = start;
    dut->i_dig_ring_tune_end = end;
    dut->i_dig_ring_tune_stride = stride;

    search_monitor.change_sample_interval(8);
    dut->i_dig_search_trig_val = 1;
    advance_clk();
    dut->i_dig_search_trig_val = 0;

    while (!dut->o_dig_search_peaks_val) {
      advance_clk();
    }

    search_monitor.change_sample_interval(2);
    advance_clk();
    dut->i_dig_search_peaks_rdy = 1;
    advance_clk();

    if (print) {
      std::cout << "Search complete, number of peaks found: "
                << (int)dut->o_dig_ring_tune_peaks_cnt << " ("
                << search_range_string() << ")" << std::endl;

      for (int i = 0; i < (int)dut->o_dig_ring_tune_peaks_cnt; i++) {
        std::cout << "Peak [" << i
                  << "]: Code: " << (int)dut->o_dig_ring_tune_peaks[i]
                  << " Pwr: " << (int)dut->o_dig_pwr_detected_peaks[i]
                  << std::endl;
      }
    }
  };

  // DUT initialization
  dut->i_pwr = 1.0;
  dut->i_wvl_ls[0] = 1300.0;
  dut->i_wvl_ls[1] = 1302.0;
  dut->i_wvl_ring = 1295.0;
  dut->i_dig_search_trig_val = 0;
  dut->i_dig_search_peaks_rdy = 0;

  dut->i_clk = 0; // Clock starts low
  dut->i_rst = 1;
  advance_clk();
  advance_clk();
  dut->i_rst = 0; // Release reset
  advance_clk();  // Wait for a clock cycle after reset

  search_routine(0, 255, 2, true);
  search_routine(140, 255, 0, true);

  search_monitor.write_csv("search_waveform.csv");

  // Clean up
  tfp->close();

  return 0;
}
