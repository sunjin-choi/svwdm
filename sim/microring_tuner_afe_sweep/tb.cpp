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
  const int code_start = 0;
  const int code_end = 255;
  const int code_count = code_end - code_start + 1;

  // DUT initialization
  dut->i_pwr = 1.0;
  dut->i_wvl_ls = 1300.0;
  dut->i_wvl_ring = 1295.0;

  dut->i_clk = 0; // Clock starts low
  tb.reset(dut->i_clk, dut->i_rst);

  // initialize sweep result vector
  csv_t sweep_result;

  for (const auto pt : DACSweep(dut->i_pwr, code_start, code_end, code_count)) {
    dut->i_pwr = pt.i_pwr;
    dut->i_dac_tune = pt.i_code;

    /*dut->eval();
     *tfp->dump(main_time);*/
    while (!dut->o_dig_pwr_thru_detect_val) {
      advance_clk();
    }

    dac_tf_t measure = pt;
    measure.o_pwr = dut->o_pwr_thru;
    sweep_result.push_back(rec_to_csv_row(measure));

    std::cout << "[ADC Output] Thru: " << (int)dut->o_adc_thru
              << " || Drop: " << (int)dut->o_adc_drop << " (256/1mW) at "
              << pt.i_code << " code" << std::endl;

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
