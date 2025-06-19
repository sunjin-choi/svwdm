//==============================================================================
// Author: Sunjin Choi
// Description: 
// Signals:
// Note: 
// Variable naming conventions:
//    signals => snake_case
//    Parameters (aliasing signal values) => SNAKE_CASE with all caps
//    Parameters (not aliasing signal values) => CamelCase
//==============================================================================

// verilog_format: off
`timescale 1ns/1ps
`default_nettype none
// verilog_format: on

module microring #(
    parameter type waves_t = waves8_t,
    /*parameter real ResonanceWavelength = 1300.0,*/
    parameter real FWHM = 10,
    parameter real TuningFullScale = 10
) (
    // input signals
    input var waves_t i_phot_waves,
    input var real i_real_wvl_ring,

    input var real i_real_tuning_dist,
    input var real i_real_temperature,

    // output signals
    output waves_t o_phot_waves_drop,
    output waves_t o_phot_waves_thru
);
  import wdm_pkg::*;

  // ----------------------------------------------------------------------
  // Signals
  // ----------------------------------------------------------------------
  real ring_resonance_wavelength;
  real ring_fwhm;
  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // Assigns
  // ----------------------------------------------------------------------
  /*initial ring_resonance_wavelength = ResonanceWavelength;*/
  initial ring_fwhm = FWHM;

  // TODO: implement temperature sensitivity
  always @(i_real_tuning_dist, i_real_temperature) begin : update_resonance
    ring_resonance_wavelength = i_real_wvl_ring + i_real_tuning_dist * TuningFullScale;
  end

  always_comb begin : ring_tf
    foreach (i_phot_waves.wave_bundle[i]) begin
      o_phot_waves_thru.wave_bundle[i] =
          ring_thru(i_phot_waves.wave_bundle[i], ring_resonance_wavelength, ring_fwhm);
      o_phot_waves_drop.wave_bundle[i] =
          ring_drop(i_phot_waves.wave_bundle[i], ring_resonance_wavelength, ring_fwhm);
    end
  end
  // ----------------------------------------------------------------------

  // ----------------------------------------------------------------------
  // Functions
  // ----------------------------------------------------------------------
  function automatic real lorentzian;
    input real x;
    input real x0;
    input real fwhm;

    begin
      lorentzian = 1 / (1 + (x - x0) ** 2 / (fwhm / 2) ** 2);
    end
  endfunction

  function automatic wave_t ring_drop;
    input wave_t ring_waves_in;
    input real ring_resonance_wavelength;
    input real ring_fwhm;

    begin
      ring_drop.power = ring_waves_in.power *
          lorentzian(ring_waves_in.wavelength, ring_resonance_wavelength, ring_fwhm);
      ring_drop.wavelength = ring_waves_in.wavelength;
    end
  endfunction

  function automatic wave_t ring_thru;
    input wave_t ring_waves_in;
    input real ring_resonance_wavelength;
    input real ring_fwhm;

    begin
      ring_thru.power = ring_waves_in.power *
          (1 - lorentzian(ring_waves_in.wavelength, ring_resonance_wavelength, ring_fwhm));
      ring_thru.wavelength = ring_waves_in.wavelength;
    end
  endfunction
  // ----------------------------------------------------------------------


endmodule

`default_nettype wire

