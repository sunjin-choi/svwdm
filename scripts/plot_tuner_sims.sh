#!/usr/bin/env bash

./utils/plot_wave ./build/sim/tuner_search_lock/search_lock_waveform.csv --state lock_state --filepath ./plots/tuner_search_lock.png

./utils/plot_wave ./build/sim/tuner_search_row/search_waveform_ring0.csv --filepath ./plots/tuner_search_row_ring0.png
./utils/plot_wave ./build/sim/tuner_search_row/search_waveform_ring1.csv --filepath ./plots/tuner_search_row_ring1.png

./utils/plot_wave ./build/sim/tuner_search/search_waveform.csv --time_col time --state_col state --filepath ./plots/tuner_search.png

