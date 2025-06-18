
/*#include "Vhello_world.h"*/
#include "Vsim.h"
#include <verilated.h>

int main() {

  Vsim *const hello = new Vsim;

  hello->eval();

  hello->final();
  delete hello;

  return 0;
}
