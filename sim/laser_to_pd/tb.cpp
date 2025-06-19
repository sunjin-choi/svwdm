#include "Vsim.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
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
  /*Vsim *const dut = new Vsim{contextp.get()};*/
  const auto dut = std::make_unique<Vsim>(contextp.get());

  dut->trace(tfp.get(), 99);
  tfp->open("waveform.vcd");

  // Time variable
  vluint64_t main_time = 0;
  const vluint64_t sim_time = 10;

  // Input values
  dut->i_pwr = 1.0;
  dut->i_wvl_center = 1300.0;
  dut->i_wvl_spacing = 1.0;

  // Evaluate
  for (; main_time < sim_time; ++main_time) {
    dut->eval();
    tfp->dump(main_time);
  }

  std::cout << "PD output: " << dut->o_pd << " (A)" << std::endl;

  // Clean up
  tfp->close();
  /*delete dut;*/
  /*delete tfp;*/
  /*delete contextp;*/

  return 0;
}
