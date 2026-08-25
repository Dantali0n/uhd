//
// Copyright 2026 Ettus Research, a National Instruments Brand
//
// SPDX-License-Identifier: LGPL-3.0-or-later
//
// Package: cic_filter_test_pkg
//
// Description:
//
//   Package containing utilities and simulation models for CIC multisample filter TBs.
//
// Parameters:
//
//   SPC          : Number of samples per clock cycle on DUT
//   ACCUM_W      : Width of a DUT input sample. Equivalent to the accumulator width.
//   COMP_W       : Width of I and Q components in the input samples. This is
//                  used to generate test inputs and should be less than or equal to
//                  ACCUM_W/2.
//

`default_nettype none

package cic_filter_test_pkg;

  import cic_utils_pkg::*;
  import cic_test_pkg::*;
  import cic_comb_filter_test_pkg::*;

  // Model the final signed CIC output quantization performed by
  // cic_barrel_shift. The CIC stages remain at full accumulator precision.
  class cic_filter_quantizer #(
    int ACCUM_W = 96,
    int SAMP_W  = 32
  );

    localparam int ACCUM_COMP_W = ACCUM_W / 2;
    localparam int SAMP_COMP_W  = SAMP_W / 2;
    localparam logic [SAMP_COMP_W-1:0] MAX_OUTPUT =
      {1'b0, {(SAMP_COMP_W-1){1'b1}}};
    localparam logic [SAMP_COMP_W-1:0] MIN_OUTPUT =
      {1'b1, {(SAMP_COMP_W-1){1'b0}}};

    typedef logic signed [ACCUM_COMP_W-1:0] accum_comp_t;
    typedef logic signed [SAMP_COMP_W-1:0]  samp_comp_t;

    // Round-half-up expressed as an addition of half an LSB before the shift,
    // deliberately formulated differently from the RTL so that a conceptual
    // error in cic_barrel_shift is not mirrored by this reference model. The
    // RTL clips instead of wrapping, which only matters when the shifted
    // result does not fit in SAMP_COMP_W bits.
    static function automatic samp_comp_t round_shift_component(
      input accum_comp_t comp_in,
      input int          shift_amount
    );
      accum_comp_t rounded;

      if (shift_amount > 0) begin
        rounded = (comp_in + (accum_comp_t'(1) << (shift_amount-1))) >>>
                  shift_amount;
      end else begin
        rounded = comp_in;
      end

      if (rounded > accum_comp_t'(signed'(MAX_OUTPUT))) begin
        return samp_comp_t'(MAX_OUTPUT);
      end
      if (rounded < accum_comp_t'(signed'(MIN_OUTPUT))) begin
        return samp_comp_t'(MIN_OUTPUT);
      end
      return samp_comp_t'(rounded[SAMP_COMP_W-1:0]);
    endfunction : round_shift_component

    static function automatic logic [SAMP_W-1:0] round_shift_sample(
      input logic [ACCUM_W-1:0] sample_in,
      input int                 shift_amount
    );
      accum_comp_t q_in;
      accum_comp_t i_in;
      samp_comp_t q_out;
      samp_comp_t i_out;

      q_in = sample_in[ACCUM_COMP_W-1:0];
      i_in = sample_in[ACCUM_W-1:ACCUM_COMP_W];
      q_out = round_shift_component(q_in, shift_amount);
      i_out = round_shift_component(i_in, shift_amount);
      return {i_out, q_out};
    endfunction : round_shift_sample

  endclass : cic_filter_quantizer

  //---------------------------------------------------------------------------
  // Bit-true simulation model of a full Nth-order CIC decimation filter.
  //
  // Chains ORDER integrators -> decimate by R -> ORDER combs (D=1),
  // processing one sample at a time (SPC-agnostic). All stages operate at
  // ACCUM_W width with modular (wrapping) two's complement arithmetic. The
  // returned samples remain at ACCUM_W precision; use cic_filter_quantizer
  // for the final rounded output conversion.
  //
  // State is created fresh on each call to process() (zero initial
  // conditions), so there is no need to explicitly clear between runs.
  //---------------------------------------------------------------------------
  class cic_filter_decim_model #(
    int ACCUM_W = 96,
    int ORDER   = 4
  );

    typedef cic_utils#(.SAMP_W(ACCUM_W)) util_c;
    typedef util_c::sample_t sample_t;
    typedef sample_t         sample_queue_t[$];

    function new();
    endfunction

    //-------------------------------------------------------------------------
    // process: run samples through the full CIC decimation chain.
    //
    // ORDER integrators (full rate) -> decimate by R -> ORDER combs (D=1).
    // All stages operate at ACCUM_W width with wrapping two's complement
    // arithmetic. State is created fresh each call (zero initial conditions).
    //
    //   samples_in   : flat queue of input samples (full rate).
    //   decim_factor : decimation ratio R (keep every R-th sample).
    //   samples_out  : flat queue of output samples (decimated rate).
    //-------------------------------------------------------------------------
    function void process(
      input  sample_queue_t samples_in,
      input  int            decim_factor,
      output sample_queue_t samples_out
    );
      sample_queue_t stage_data, next_data;

      stage_data = samples_in;

      // ORDER integrator stages (full input rate).
      // SAMP_W == ACCUM_W so the saturate is a no-op between stages.
      begin
        automatic cic_integrator_model #(
          .SAMP_W (ACCUM_W),
          .ACCUM_W(ACCUM_W),
          .ORDER  (ORDER)
        ) integ = new();
        integ.process_packet(stage_data, next_data);
        stage_data = next_data;
      end

      // Decimate by R: keep every R-th sample.
      next_data = {};
      foreach (stage_data[i]) begin
        if (i % decim_factor == 0)
          next_data.push_back(stage_data[i]);
      end
      stage_data = next_data;

      // ORDER comb stages (decimated rate, fixed delay D=1).
      repeat (ORDER) begin
        automatic cic_comb_filter_test_model #(
          .ACCUM_W(ACCUM_W)
        ) comb = new();
        comb.process_samples(stage_data, next_data);
        stage_data = next_data;
      end

      samples_out = stage_data;
    endfunction

  endclass : cic_filter_decim_model


  //---------------------------------------------------------------------------
  // Bit-true simulation model of a full Nth-order CIC interpolation filter.
  //
  // Chains ORDER combs (D=1, input rate) -> upsample by R -> ORDER integrators
  // (full output rate), processing one sample at a time (SPC-agnostic). All
  // stages operate at ACCUM_W width with modular (wrapping) two's complement
  // arithmetic. The returned samples remain at ACCUM_W precision; use
  // cic_filter_quantizer for the final rounded output conversion.
  //
  // State is created fresh on each call to process() (zero initial
  // conditions), so there is no need to explicitly clear between runs.
  //---------------------------------------------------------------------------
  class cic_filter_interp_model #(
    int ACCUM_W = 96,
    int ORDER   = 4
  );

    typedef cic_utils#(.SAMP_W(ACCUM_W)) util_c;
    typedef util_c::sample_t sample_t;
    typedef sample_t         sample_queue_t[$];

    function new();
    endfunction

    //-------------------------------------------------------------------------
    // process: run samples through the full CIC interpolation chain.
    //
    // ORDER combs (D=1, input rate) -> upsample by R -> ORDER integrators
    // (full output rate). All stages operate at ACCUM_W width with wrapping
    // two's complement arithmetic. State is created fresh each call (zero
    // initial conditions).
    //
    //   samples_in    : flat queue of input samples (lower rate).
    //   interp_factor : interpolation ratio R (produce R outputs per input).
    //   samples_out   : flat queue of output samples (higher rate).
    //-------------------------------------------------------------------------
    function void process(
      input  sample_queue_t samples_in,
      input  int            interp_factor,
      output sample_queue_t samples_out
    );
      sample_queue_t stage_data, next_data;

      stage_data = samples_in;

      // ORDER comb stages (input rate, fixed delay D=1).
      repeat (ORDER) begin
        automatic cic_comb_filter_test_model #(
          .ACCUM_W(ACCUM_W)
        ) comb = new();
        comb.process_samples(stage_data, next_data);
        stage_data = next_data;
      end

      // Upsample by R: each input sample is followed by R-1 zeros.
      next_data = {};
      foreach (stage_data[i]) begin
        next_data.push_back(stage_data[i]);
        repeat (interp_factor - 1) begin
          next_data.push_back('0);
        end
      end
      stage_data = next_data;

      // ORDER integrator stages (full output rate).
      // SAMP_W == ACCUM_W so the saturate is a no-op between stages.
      begin
        automatic cic_integrator_model #(
          .SAMP_W (ACCUM_W),
          .ACCUM_W(ACCUM_W),
          .ORDER  (ORDER)
        ) integ = new();
        integ.process_packet(stage_data, next_data);
        stage_data = next_data;
      end

      samples_out = stage_data;
    endfunction

  endclass : cic_filter_interp_model

endpackage : cic_filter_test_pkg

`default_nettype wire
