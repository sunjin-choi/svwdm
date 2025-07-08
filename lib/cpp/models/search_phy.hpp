#ifndef SEARCH_PHY_HPP
#define SEARCH_PHY_HPP

#include <array>
#include <cstdint>

namespace search_phy {

enum class search_state_e : uint8_t {
    SEARCH_IDLE = 0,
    SEARCH_INIT = 1,
    SEARCH_ACTIVE = 2,
    SEARCH_DONE = 3,
    SEARCH_ERROR = 4,
    SEARCH_INTR = 5
};

class SearchPhyModel {
public:
    static constexpr int DAC_WIDTH = 8;
    static constexpr int ADC_WIDTH = 8;
    static constexpr int NUM_TARGET = 8;
    static constexpr int PEAK_WINDOW_SIZE = 3; // simple three-sample window

    SearchPhyModel() { reset(); }

    void configure(uint8_t start, uint8_t end, uint8_t stride) {
        cfg_start_ = start;
        cfg_end_ = end;
        cfg_stride_ = stride;
    }

    void reset() {
        state_ = search_state_e::SEARCH_IDLE;
        ring_tune_ = 0;
        ring_tune_step_ = 1;
        sample_cnt_ = 0;
        peak_count_ = 0;
        tune_window_.fill(0);
        pwr_window_.fill(0);
        ring_tune_peaks_.fill(0);
        pwr_peaks_.fill(0);
    }

    void start() {
        reset();
        state_ = search_state_e::SEARCH_ACTIVE;
        ring_tune_ = cfg_start_;
        ring_tune_step_ = static_cast<uint8_t>(1u << cfg_stride_);
    }

    void step(uint8_t power_sample) {
        if(state_ != search_state_e::SEARCH_ACTIVE) return;

        for(int i = PEAK_WINDOW_SIZE-1; i > 0; --i) {
            tune_window_[i] = tune_window_[i-1];
            pwr_window_[i] = pwr_window_[i-1];
        }
        tune_window_[0] = ring_tune_;
        pwr_window_[0] = power_sample;

        if(sample_cnt_ >= 2) {
            if(pwr_window_[1] > pwr_window_[0] && pwr_window_[1] > pwr_window_[2]) {
                if(peak_count_ < NUM_TARGET) {
                    ring_tune_peaks_[peak_count_] = tune_window_[1];
                    pwr_peaks_[peak_count_] = pwr_window_[1];
                    ++peak_count_;
                }
            }
        }

        ++sample_cnt_;
        ring_tune_ = static_cast<uint8_t>(ring_tune_ + ring_tune_step_);
        if(ring_tune_ > cfg_end_) {
            state_ = search_state_e::SEARCH_DONE;
        }
    }

    const std::array<uint8_t, NUM_TARGET>& ring_tune_peaks() const { return ring_tune_peaks_; }
    const std::array<uint8_t, NUM_TARGET>& pwr_peaks() const { return pwr_peaks_; }
    uint8_t peaks_cnt() const { return peak_count_; }
    uint8_t ring_tune() const { return ring_tune_; }
    search_state_e state() const { return state_; }

private:
    uint8_t cfg_start_ = 0;
    uint8_t cfg_end_ = 0;
    uint8_t cfg_stride_ = 0;

    search_state_e state_ = search_state_e::SEARCH_IDLE;
    uint8_t ring_tune_ = 0;
    uint8_t ring_tune_step_ = 1;
    uint8_t sample_cnt_ = 0;

    std::array<uint8_t, PEAK_WINDOW_SIZE> tune_window_{};
    std::array<uint8_t, PEAK_WINDOW_SIZE> pwr_window_{};

    std::array<uint8_t, NUM_TARGET> ring_tune_peaks_{};
    std::array<uint8_t, NUM_TARGET> pwr_peaks_{};
    uint8_t peak_count_ = 0;
};

} // namespace search_phy

#endif // SEARCH_PHY_HPP
