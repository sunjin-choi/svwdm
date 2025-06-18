
`default_nettype none

package wdm_pkg;

  typedef real wvl_t;
  typedef real pwr_t;

  typedef struct {
    wvl_t wavelength;
    pwr_t power;
  } wave_t;

  `define DEFINE_WAVES_TYPE(WIDTH) \
    typedef struct { wave_t wave_bundle[WIDTH-1:0]; } waves``WIDTH``_t;

  /*  typedef struct {wave_t wave_bundle[0:0];} waves1_t;
 *
 *  typedef struct {wave_t wave_bundle[3:0];} waves4_t;
 *
 *  typedef struct {wave_t wave_bundle[7:0];} waves8_t;
 *
 *  typedef struct {wave_t wave_bundle[15:0];} waves16_t;*/

  `DEFINE_WAVES_TYPE(1)
  `DEFINE_WAVES_TYPE(4)
  `DEFINE_WAVES_TYPE(8)
  `DEFINE_WAVES_TYPE(16)

  `define DECLARE_WAVES_TYPE(WIDTH) \
    typedef waves``WIDTH``_t WAVES_TYPE; \
    localparam int WAVES_WIDTH = WIDTH; \


endpackage

