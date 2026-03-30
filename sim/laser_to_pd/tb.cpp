#include "Vsim.h"
#include "testbench/verilator_tb.hpp"
#include <iostream>

int main(int argc, char **argv) {
  VerilatorTb<Vsim> tb(argc, argv);
  auto *dut = tb.dut();

  // Time variable
  vluint64_t main_time = 0;
  const vluint64_t sim_time = 10;

  // Input values
  dut->i_pwr = 1.0;
  dut->i_wvl_center = 1300.0;
  dut->i_wvl_spacing = 1.0;

  // Evaluate
  for (; main_time < sim_time; ++main_time) {
    tb.advance_time(1);
  }

  std::cout << "PD output: " << dut->o_pd << " (A)" << std::endl;

  return 0;
}
