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

## MiSTer CRT Adjust

- `rtl/crt_adjust.sv`
- https://github.com/rmonic79/MiSTer-CRT-Adjust
- Pinned revision `9616f9295c807b95a9cd0961981ebf08dbbabf08`
- GPL-3.0-or-later; author Umberto Parisi (`rmonic79`), with contributions
  acknowledged in the upstream source.
- Integrated core-side with all three upstream controls: horizontal size,
  horizontal position, and vertical shift. The Universal 312x264 raster uses
  upstream `HPOS_SYNCSHIFT` mode because its 240-pixel active area has
  asymmetric horizontal blanking.

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
