#include "Vsim.h"
#include "testbench/verilator_tb.hpp"
#include "utils/sweep.hpp"
#include <csv2/writer.hpp>
#include <fstream>
#include <iostream>

int main(int argc, char **argv) {
  VerilatorTb<Vsim> tb(argc, argv);
  auto *dut = tb.dut();

  // Time variable
  vluint64_t main_time = 0;

  // Sweep parameters
  const double wvl_start = 1295.0;
  const double wvl_end = 1305.0;
  const double wvl_count = 100;

  dut->i_pwr = 1.0;
  dut->i_wvl_ls = wvl_start;
  dut->i_wvl_ring = 1300.0;

  /*auto sweep = WavelengthSweep(dut->i_pwr, wvl_start, wvl_end, wvl_count);*/

  /*// Evaluate
   *for (; main_time < sim_time; ++main_time) {
   *  dut->eval();
   *  tfp->dump(main_time);
   *}*/

  // initialize sweep result vector
  csv_t sweep_result;

  for (const auto pt :
       WavelengthSweep(dut->i_pwr, wvl_start, wvl_end, wvl_count)) {
    dut->i_pwr = pt.i_pwr;
    dut->i_wvl_ls = pt.i_wvl;

    tb.advance_time(1);

    wvl_tf_t measure = pt;
    measure.o_pwr = dut->o_pwr_thru;
    sweep_result.push_back(rec_to_csv_row(measure));

    std::cout << "i_pwr: " << measure.i_pwr << ", i_wvl: " << measure.i_wvl
              << ", o_pwr: " << measure.o_pwr << std::endl;
    main_time += 1; // Increment time by 1 ps for each iteration
  }

  std::ofstream stream("sweep.csv");
  csv2::Writer<csv2::delimiter<','>> writer(stream);

  // write header
  writer.write_row(csv_row_t{"i_pwr", "i_wvl", "o_pwr"});
  writer.write_rows(sweep_result);
  stream.close();

  return 0;
}
