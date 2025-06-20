#include "Vsim.h"
#include "sweep.hpp"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include <csv2/writer.hpp>
#include <fstream>
#include <iostream>
#include <memory>

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
  const vluint64_t sim_time = 10;

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

    dut->eval();
    tfp->dump(main_time);

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

  /*std::cout << "PD output: " << dut->o_pd << " (A)" << std::endl;*/

  // Clean up
  tfp->close();

  return 0;
}
