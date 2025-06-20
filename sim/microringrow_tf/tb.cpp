#include "Vsim.h"
#include "utils/sweep.hpp"
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
  const double wvl_count = 200;

  dut->i_pwr = 1000.0;
  dut->i_wvl_ls = wvl_start;

  // setup a range of wavelengths
  const std::array<double, 8> wvl_ring = {1297.0, 1298.0, 1299.0, 1300.0,
                                          1301.0, 1302.0, 1303.0, 1304.0};

  int wvl_idx = 0;
  for (const auto wvl : wvl_ring) {
    dut->i_wvl_ring[wvl_idx] = wvl;
    wvl_idx++;
  }

  // initialize sweep result vector
  csv_t sweep_result_thru;
  csv_t sweep_result_drop[8];

  for (const auto pt :
       WavelengthSweep(dut->i_pwr, wvl_start, wvl_end, wvl_count)) {
    dut->i_pwr = pt.i_pwr;
    dut->i_wvl_ls = pt.i_wvl;

    dut->eval();
    tfp->dump(main_time);

    wvl_tf_t measure_thru = pt;
    wvl_tf_t measure_drop[8];

    measure_thru.o_pwr = dut->o_pwr_thru;
    sweep_result_thru.push_back(rec_to_csv_row(measure_thru));

    for (int i = 0; i < 8; ++i) {
      measure_drop[i] = pt; // Copy the base measurement
      measure_drop[i].o_pwr = dut->o_pwr_drop[i];
      sweep_result_drop[i].push_back(rec_to_csv_row(measure_drop[i]));
      i++;
    }

    std::cout << "i_pwr: " << measure_thru.i_pwr
              << ", i_wvl: " << measure_thru.i_wvl
              << ", o_pwr_thru: " << measure_thru.o_pwr
              << ", o_pwr_drop[1]: " << measure_drop[0].o_pwr << std::endl;
    main_time += 1; // Increment time by 1 ps for each iteration
  }

  std::ofstream stream("sweep_thru.csv");
  csv2::Writer<csv2::delimiter<','>> writer(stream);

  // write header
  writer.write_row(csv_row_t{"i_pwr", "i_wvl", "o_pwr_thru"});
  writer.write_rows(sweep_result_thru);
  stream.close();

  /*std::cout << "PD output: " << dut->o_pd << " (A)" << std::endl;*/

  // Clean up
  tfp->close();

  return 0;
}
