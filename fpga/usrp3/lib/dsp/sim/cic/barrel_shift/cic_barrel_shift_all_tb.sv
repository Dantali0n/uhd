//
// Copyright 2026 Ettus Research, a National Instruments Brand
//
// SPDX-License-Identifier: LGPL-3.0-or-later
//
// Module: cic_barrel_shift_all_tb
//
// Description:
//
//   Run direct CIC barrel-shift rounding tests across single- and
//   multisample configurations.
//

`default_nettype none

module cic_barrel_shift_all_tb;

  cic_barrel_shift_tb #(
    .SPC      (4),
    .IN_WIDTH (32),
    .OUT_WIDTH(16),
    .MAX_RATE (4),
    .ORDER    (2)
  ) tb_compact ();

  cic_barrel_shift_tb #(
    .SPC      (1),
    .IN_WIDTH (96),
    .OUT_WIDTH(32),
    .MAX_RATE (255),
    .ORDER    (4)
  ) tb_spc1 ();

  cic_barrel_shift_tb #(
    .SPC      (4),
    .IN_WIDTH (96),
    .OUT_WIDTH(32),
    .MAX_RATE (255),
    .ORDER    (4)
  ) tb_spc4 ();

  cic_barrel_shift_tb #(
    .SPC      (8),
    .IN_WIDTH (96),
    .OUT_WIDTH(32),
    .MAX_RATE (255),
    .ORDER    (4)
  ) tb_spc8 ();

endmodule : cic_barrel_shift_all_tb

`default_nettype wire
