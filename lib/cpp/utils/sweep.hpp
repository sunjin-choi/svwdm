#ifndef SWEEP_H
#define SWEEP_H

typedef std::vector<std::string> csv_row_t;
typedef std::vector<csv_row_t> csv_t;

// ------------------
// Template Class for Dynamic Record Conversion and Iteration
// ------------------
template <typename Rec> csv_row_t rec_to_csv_row(const Rec &rec);

template <typename Derived, typename Rec> class SweepBase {
public:
  struct iterator {

    using value_type = Rec;
    using reference = Rec;
    using pointer = Rec *;
    using iterator_category = std::input_iterator_tag;
    using difference_type = std::ptrdiff_t;

    const Derived *parent;
    int idx;
    Rec rec;

    iterator(const Derived *parent, int idx)
        : parent(parent), idx(idx), rec(parent->get_rec(idx)) {
      update();
    }
    void update() {
      ++idx;
      parent->update_rec(rec, idx);
    }

    Rec &operator*() { return rec; }
    iterator &operator++() {
      update();
      return *this;
    }
    bool operator!=(const iterator &other) const { return idx != other.idx; }
  };

  virtual ~SweepBase() = default;
  virtual int count() const = 0;
  virtual Rec get_rec(int idx) const = 0;

  iterator begin() const {
    return iterator(static_cast<const Derived *>(this), 0);
  }
  iterator end() const {
    return iterator(static_cast<const Derived *>(this),
                    static_cast<const Derived *>(this)->count());
  }
};

// ------------------
// Wavelength Sweep
// ------------------
typedef struct {
  double i_pwr;
  double i_wvl;
  double o_pwr;
} wvl_tf_t;

class WavelengthSweep : public SweepBase<WavelengthSweep, wvl_tf_t> {

public:
  WavelengthSweep(double i_pwr, double wvl_start, double wvl_end, int count)
      : i_pwr_(i_pwr), wvl_start_(wvl_start), wvl_end_(wvl_end), count_(count) {
  }

  int count() const override { return count_; }

  void update_rec(wvl_tf_t &rec, int idx) const {
    double wvl = wvl_start_ + (wvl_end_ - wvl_start_) * idx / (count_ - 1);
    rec.i_pwr = i_pwr_;
    rec.i_wvl = wvl;
    rec.o_pwr = 0.0; // Placeholder for output power
  }

  wvl_tf_t get_rec(int idx) const override {
    wvl_tf_t rec;
    update_rec(rec, idx);
    return rec;
  }

private:
  double i_pwr_;
  double wvl_start_;
  double wvl_end_;
  int count_;
};

inline csv_row_t rec_to_csv_row(const wvl_tf_t &rec) {
  return {std::to_string(rec.i_pwr), std::to_string(rec.i_wvl),
          std::to_string(rec.o_pwr)};
}

// ------------------
// DAC Sweep
// ------------------
typedef struct {
  double i_pwr;
  int i_code;
  double o_pwr;
} dac_tf_t;

class DACSweep : public SweepBase<DACSweep, dac_tf_t> {
public:
  DACSweep(double i_pwr, int code_start, int code_end, int count)
      : i_pwr_(i_pwr), code_start_(code_start), code_end_(code_end),
        count_(count) {}

  int count() const override { return count_; }

  void update_rec(dac_tf_t &rec, int idx) const {
    int code = code_start_ + (code_end_ - code_start_) * idx / (count_ - 1);
    rec.i_pwr = i_pwr_;
    rec.i_code = static_cast<int>(code);
    rec.o_pwr = 0.0; // Placeholder for output power
  }

  dac_tf_t get_rec(int idx) const override {
    dac_tf_t rec;
    update_rec(rec, idx);
    return rec;
  }

private:
  double i_pwr_;
  int code_start_;
  int code_end_;
  int count_;
};

inline csv_row_t rec_to_csv_row(const dac_tf_t &rec) {
  return {std::to_string(rec.i_pwr), std::to_string(rec.i_code),
          std::to_string(rec.o_pwr)};
}

#endif // SWEEP_H
