#include "Vsim.h"
#include "testbench/verilator_tb.hpp"
#include "utils/sweep.hpp"
#include <csv2/writer.hpp>
#include <fstream>
#include <iostream>

int main(int argc, char **argv) {
  VerilatorTb<Vsim> tb(argc, argv);
  auto *dut = tb.dut();

  auto advance_clk = [&]() { tb.step_clk(dut->i_clk); };

  // Sweep parameters
  const double wvl_start = 1295.0;
  const double wvl_end = 1305.0;
  const double wvl_count = 100;

  // DUT initialization
  dut->i_pwr = 1.0;
  dut->i_wvl_ls = wvl_start;
  dut->i_wvl_ring = 1300.0;

  dut->i_clk = 0; // Clock starts low
  tb.reset(dut->i_clk, dut->i_rst);

  // initialize sweep result vector
  csv_t sweep_result;

  for (const auto pt :
       WavelengthSweep(dut->i_pwr, wvl_start, wvl_end, wvl_count)) {
    dut->i_pwr = pt.i_pwr;
    dut->i_wvl_ls = pt.i_wvl;

    /*dut->eval();
     *tfp->dump(main_time);*/
    while (!dut->o_dig_pwr_thru_detect_fire) {
      advance_clk();
    }

    wvl_tf_t measure = pt;
    measure.o_pwr = dut->o_pwr_thru;
    sweep_result.push_back(rec_to_csv_row(measure));

    std::cout << "[ADC Output] Thru: " << (int)dut->o_adc_thru
              << " || Drop: " << (int)dut->o_adc_drop << " (256/1mW) at "
              << pt.i_wvl << " nm" << std::endl;

    std::cout << "[PWR DETECT] Thru: " << (int)dut->o_dig_pwr_thru_detect
              << std::endl;

    advance_clk();
  }

  std::ofstream stream("sweep.csv");
  csv2::Writer<csv2::delimiter<','>> writer(stream);

  // write header
  writer.write_row(csv_row_t{"i_pwr", "i_wvl", "o_pwr"});
  writer.write_rows(sweep_result);
  stream.close();

  return 0;
}
