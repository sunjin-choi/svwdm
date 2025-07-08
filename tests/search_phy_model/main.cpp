#include "models/search_phy.hpp"
#include <cassert>
#include <iostream>

using namespace search_phy;

static int power_func(int tune) {
    int diff1 = std::abs(tune - 5);
    int diff2 = std::abs(tune - 15);
    int pwr = 10;
    if(diff1 < 3) pwr += (3 - diff1) * 40;
    if(diff2 < 3) pwr += (3 - diff2) * 40;
    return pwr & 0xFF;
}

int main() {
    SearchPhyModel model;
    model.configure(0, 20, 0); // sweep 0..20 step 1
    model.start();

    while(model.state() == search_state_e::SEARCH_ACTIVE) {
        int tune = model.ring_tune();
        model.step(power_func(tune));
    }

    assert(model.state() == search_state_e::SEARCH_DONE);

    const auto &peaks = model.ring_tune_peaks();
    const auto &pwrs = model.pwr_peaks();
    assert(model.peaks_cnt() >= 2);
    assert(peaks[0] == 5);
    assert(peaks[1] == 15);

    std::cout << "Peaks detected: " << (int)model.peaks_cnt() << "\n";
    for(int i = 0; i < model.peaks_cnt(); ++i) {
        std::cout << "Peak " << i << " code=" << (int)peaks[i]
                  << " pwr=" << (int)pwrs[i] << "\n";
    }
    return 0;
}
