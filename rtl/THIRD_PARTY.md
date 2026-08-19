# Third-party RTL

## T80 Z80

- `rtl/t80/`
- OpenCores T80 / MiSTer packaging, Daniel Wallner et al. and Sorgelig
- BSD-style licence in file headers and `rtl/t80/README.md`

## JT89 SN76489A

- `rtl/jt89/`
- https://github.com/jotego/jt89
- GPL-3.0-or-later; author Jose Tejada Gomez
- The vendored copy includes the SN76489A LFSR and register-6 reset corrections
  documented by the source project's `THIRD_PARTY.md` and checked against MAME.

## JT5205 MSM5205

- `rtl/jt5205/`
- https://github.com/jotego/jt5205
- Pinned revision `cd3cb834764534c205b8e912b1bea26570a36f7d`
- GPL-3.0-or-later; author Jose Tejada Gomez
- Used by the Indoor Soccer and American Soccer hardware profile at the
  verified 384 kHz input clock and S48 four-bit mode.

## JTFRAME clocking primitives

- `rtl/jtframe/`
- https://github.com/jotego/jtcores (jtframe module: `modules/jtframe/hdl/clocking/`)
- Pinned revisions `a0466f2682de3888771b3efde1666a17a56627cb` (jtframe_frac_cen.v),
  `e00b18cbb1769e72d1ba58015cf4ae874d4ded32` (jtframe_rst_sync.v)
- GPL-3.0-or-later; author Jose Tejada Gomez
- Used to generate the board's fractional CPU/PSG (4 MHz) and MCLK (9.828 MHz) clock
  enables and to synchronize the machine-reset release edge, replacing hand-rolled
  phase-accumulator equivalents with the upstream jtframe primitives.

## JTFRAME OSD video/credits/DB15

- `rtl/jtframe_osd/`
- https://github.com/jotego/jtcores (jtframe module: `modules/jtframe/hdl/`)
- Pinned revisions: `29386d0512118da34eb95994b0389b0fc5e1d14e` (jtframe_resync.v),
  `c98feaed7e346ace1accd12b8fe637af3ff36b2c` (jtframe_hsize.v),
  `a652729fbf308cf40d5e5b700bed1fc581098106` (jtframe_linebuf.v),
  `a20b61629dd812997d7621e27ac3a5b17a5d733a` (jtframe_rpwp_ram.v),
  `01685a56cb54c22718da2e8e787f4d9e6c7bc941` (jtframe_dual_ram.v, jtframe_ram.v),
  `31141e94a728f1605baf5026b4f5085e8e4c8a3d` (jtframe_font.v),
  `91841df549070c2ae0835aa2331dc8a0d2ee6785` (jtframe_credits.v)
- GPL-3.0-or-later; author Jose Tejada Gomez
- Replaces rmonic79/MiSTer-CRT-Adjust for OSD consistency with jtframe-based
  cores: `jtframe_resync` provides CRT H/V offset (raw-analog side, same role
  crt_adjust's H-Position/V-Shift played), `jtframe_hsize` provides CRT
  H-scale (crt_adjust's H-Size). `jtframe_credits`/`jtframe_font`/
  `jtframe_dual_ram`/`jtframe_ram` implement the "Show credits in pause"
  overlay, with `rtl/jtframe_osd/msg.txt` as the editable source text and
  `rtl/jtframe_osd/msg2bin.py` (a from-scratch reimplementation of
  jtcores' `modules/jtframe/src/jtframe/msg/msg.go` encoder, since this repo
  has no Go toolchain) regenerating `msg.bin` from it -- rerun
  `python3 rtl/jtframe_osd/msg2bin.py` after editing msg.txt.
- `rtl/jtframe_osd/font0.hex` is jtframe's own 8x8 bitmap font asset, copied
  verbatim (`modules/jtframe/bin/font0.hex`).
- `rtl/jtframe_osd/joy_db15.v` provides the "User port: DB15 Joystick"
  option (Antonio Villena's DB15 splitter protocol). Sourced from
  https://github.com/MiSTer-devel/Arcade-SNK_TripleZ80_MiSTer, pinned
  revision `27870c5d722267096682b269116552daadd35aa7` -- this is the
  standard MiSTer-devel `sys/`-adjacent joy_db15.v used across many arcade
  cores, not jtframe-specific, vendored from a real core repo since it
  isn't part of this project's own `sys/`.
- `video_freak.sv` and `math.sv` (Scale / Vertical Crop) were already
  vendored in `sys/` but unused; this round wires them up. Crop Offset (the
  jtframe cfgstr's separate fine-offset control) was not implemented: its
  option-label-to-signed-offset mapping could not be verified against a
  consistent formula in the available jtframe source, so it was left out
  rather than guessed. Vertical Crop itself (on/off, fixed 216-line target)
  does not depend on that mapping and is fully wired.
- `jtframe_hsize`'s `pxl2_cen` port has no verified target oversampling
  ratio in this repo (jtcores' own convention derives it from each game
  core's own clock domain, which mrdo does not replicate); it is tied to a
  constant always-enabled `1'b1` instead, which is always functionally
  correct for that port's own internal fractional accumulator, just not
  power-optimal.

## MiSTer framework

- `sys/`, `rtl/pause.v`, `rtl/pll.*`
- Copied from the current local aCORES Ikki core/MiSTer template.
- The game PLL's generated output parameters were changed to 49.152 MHz and
  24.576 MHz for this board; the surrounding MiSTer framework is otherwise
  retained.
- `sys/osd.v`'s `OSD_COLOR` was widened from stock Template's 3-bit single-hue
  parameter to jotego jtframe's 6-bit two-bit-per-channel tint convention
  (`modules/jtframe/target/mister/hdl/sys/osd.sv`, jtcores
  `modules/jtframe/doc/osd.md`), set to `6'h3f` (gray, "mature core" per
  jtframe's documented maturity-status meaning). Only the tint/blend formula
  was ported (the `logo_blank`-true branch); jtframe's logo-in-background
  image system was not, so this core has no OSD logo watermark.

## Mr. Do! reference

- `references/Arcade-MrDo_MiSTer/`
- Darren Olafson, GPL-2.0-or-later reference core
- Used for MiSTer conventions and Universal-era common-IP comparison. Castle
  board logic in `rtl/docastle_*.sv` is a new implementation from the service
  manual and MAME driver.

## CF37201N decap reference

- https://github.com/furrtek/SiliconRE/tree/master/Misc/CF37201N
- Pinned revision `7c94fad788c33ff696ad7f07703b1dc303e3230c`.
- Upstream is GPL-2.0. The user explicitly approved consulting this material.
- `rtl/docastle_cf37201.sv` and the optional framebuffer are independently
  expressed synchronous models derived from the published decap observations,
  pinout and schematic. The upstream reproduction RTL was not copied into this
  tree; its transparent-latch structure and documented uncertain equations are
  deliberately not transplanted.
- The proven direct renderer remains the default until the optional framebuffer
  has stronger behavioral or physical-board evidence.
