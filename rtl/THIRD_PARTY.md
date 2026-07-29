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

## MiSTer framework

- `sys/`, `rtl/pause.v`, `rtl/pll.*`
- Copied from the current local aCORES Ikki core/MiSTer template.
- The game PLL's generated output parameters were changed to 49.152 MHz and
  24.576 MHz for this board; the surrounding MiSTer framework is otherwise
  retained.

## Mr. Do! reference

- `references/Arcade-MrDo_MiSTer/`
- Darren Olafson, GPL-2.0-or-later reference core
- Used for MiSTer conventions and Universal-era common-IP comparison. Castle
  board logic in `rtl/docastle_*.sv` is a new implementation from the service
  manual and MAME driver.

## CF37201N decap reference

- https://github.com/furrtek/SiliconRE/tree/master/Misc/CF37201N
- Used only as hardware-behavior evidence. No SiliconRE RTL is included.
- The published GPL-2.0 licensing has not been established as compatible with
  this GPL-3.0-only tree, and the reproduction source documents uncertain
  equations. Any future custom-chip implementation must pass the license and
  independent-verification gate in `docs/UNIVERSAL_DOCASTLE_PLAN.md`.
