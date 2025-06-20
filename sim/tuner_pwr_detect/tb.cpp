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
  /*const vluint64_t sim_time = 10;*/
  const vluint64_t clk_period = 10;

  auto advance_half_clk = [&]() {
    main_time += clk_period / 2;
    dut->i_clk = !dut->i_clk;
    dut->eval();
    /*tfp->dump(main_time);*/
  };

  auto advance_clk = [&]() {
    advance_half_clk();
    advance_half_clk();
    tfp->dump(main_time);
  };

  // Sweep parameters
  const double wvl_start = 1295.0;
  const double wvl_end = 1305.0;
  const double wvl_count = 100;

  // DUT initialization
  dut->i_pwr = 1.0;
  dut->i_wvl_ls = wvl_start;
  dut->i_wvl_ring = 1300.0;

  dut->i_clk = 0; // Clock starts low
  dut->i_rst = 1;
  advance_clk();
  advance_clk();
  dut->i_rst = 0; // Release reset
  advance_clk();  // Wait for a clock cycle after reset

  // initialize sweep result vector
  csv_t sweep_result;

  for (const auto pt :
       WavelengthSweep(dut->i_pwr, wvl_start, wvl_end, wvl_count)) {
    dut->i_pwr = pt.i_pwr;
    dut->i_wvl_ls = pt.i_wvl;

    /*dut->eval();
     *tfp->dump(main_time);*/
    while (!dut->o_dig_pwr_thru_detect_val) {
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

  /*std::cout << "PD output: " << dut->o_pd << " (A)" << std::endl;*/

  // Clean up
  tfp->close();

  return 0;
}
