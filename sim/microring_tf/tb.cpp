#include "Vsim.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include <csv2/writer.hpp>
#include <fstream>
#include <iostream>
#include <memory>

typedef struct {
  double i_pwr;
  double i_wvl;
  double o_pwr;
} tf_t;

/*typedef tf_t sweep_record;*/
typedef std::vector<std::string> csv_row_t;

typedef std::vector<tf_t> tf_sweep_t;
typedef std::vector<csv_row_t> tf_sweep_csv_t;

static inline csv_row_t tf_to_csv_row(const tf_t &tf) {
  std::vector<std::string> row;
  row.push_back(std::to_string(tf.i_pwr));
  row.push_back(std::to_string(tf.i_wvl));
  row.push_back(std::to_string(tf.o_pwr));
  return row;
}

class WavelengthSweep {
public:
  struct iterator {
    using value_type = tf_t;
    using reference = tf_t;
    using pointer = tf_t;
    using iterator_category = std::input_iterator_tag;
    using difference_type = std::ptrdiff_t;

    int idx;
    tf_t tf;
    double i_pwr, start, spacing;
    int count;

    iterator(int i, double pwr, double wvl_start, double wvl_spacing, int cnt)
        : idx(i), i_pwr(pwr), start(wvl_start), spacing(wvl_spacing),
          count(cnt) {
      update();
    }
    void update() {
      ++idx;
      tf.i_pwr = i_pwr;
      tf.i_wvl = start + idx * spacing;
      tf.o_pwr = 0.0; // Placeholder for output power
    }

    tf_t operator*() const { return tf; }

    iterator &operator++() {
      update();
      return *this;
    }

    bool operator!=(const iterator &other) const { return idx != other.idx; }
  };

  WavelengthSweep(double i_pwr, double wvl_start, double wvl_end, int count)
      : i_pwr_(i_pwr), wvl_start_(wvl_start), wvl_end_(wvl_end), count_(count) {
  }

  iterator begin() const {
    return iterator(0, i_pwr_, wvl_start_, (wvl_end_ - wvl_start_) / count_,
                    count_);
  }
  iterator end() const {
    return iterator(count_, i_pwr_, wvl_start_,
                    (wvl_end_ - wvl_start_) / count_, count_);
  }

private:
  double i_pwr_;
  double wvl_start_;
  double wvl_end_;
  int count_;
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
  tf_sweep_csv_t sweep_result;

  for (const auto pt :
       WavelengthSweep(dut->i_pwr, wvl_start, wvl_end, wvl_count)) {
    dut->i_pwr = pt.i_pwr;
    dut->i_wvl_ls = pt.i_wvl;

    dut->eval();
    tfp->dump(main_time);

    tf_t measure = pt;
    measure.o_pwr = dut->o_pwr_thru;
    sweep_result.push_back(tf_to_csv_row(measure));

    main_time += 1; // Increment time by 1 ps for each iteration
  }

  std::ofstream stream("sweep.csv");
  csv2::Writer<csv2::delimiter<','>> writer(stream);

  // write header
  writer.write_row(std::vector<std::string>{"i_pwr", "i_wvl", "o_pwr"});
  writer.write_rows(sweep_result);
  stream.close();

  /*std::cout << "PD output: " << dut->o_pd << " (A)" << std::endl;*/

  // Clean up
  tfp->close();

  return 0;
}
