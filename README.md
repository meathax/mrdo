# Arcade: Universal Do! Castle Hardware (MiSTer)

One runtime-selectable FPGA core for Universal's Do's Castle board family,
covering nine officially released games on three related hardware profiles
(Castle, Run Run, and Soccer). A single MRA is provided per game; each MRA
loads the same core and selects its profile automatically.

## Supported sets

| ID | MAME set | Game | Profile | Rotation |
|---:|---|---|---|---|
| 00 | docastle | Mr. Do's Castle | Castle | ROT270 |
| 01 | douni | Mr. Do! vs. Unicorns | Castle | ROT270 |
| 02 | dorunrun | Do! Run Run | Run Run | ROT0 |
| 03 | dowild | Mr. Do's Wild Ride | Run Run | ROT0 |
| 04 | jjack | Jumping Jack | Run Run | ROT270 |
| 05 | kickridr | Kick Rider | Run Run | ROT0 |
| 06 | spiero | Super Pierrot | Run Run | ROT0 |
| 07 | idsoccer | Indoor Soccer | Soccer | ROT0 |
| 08 | asoccer | American Soccer | Soccer | ROT0 |

The core models three 4 MHz Z80s, the cycle-sensitive main/sub WAIT
handshake, the TMS1025 input pipeline, four SN76489A PSGs with READY-driven
wait, live board-relevant HD6845 registers and raster outputs, profile-specific
CPU maps and tile priority, standard and Soccer sprite formats, Soccer
dual-stick inputs, and Soccer MSM5205 ADPCM. It also includes the main-board
watchdog and a decap-informed synchronous model of the third-CPU/CF37201
sprite doorway used by the Castle profile. The wrapper provides OSD-controlled
CRT H-Size, H-Position, and V-Shift.

## PCB accuracy

The core is built from primary hardware evidence rather than emulator
behaviour alone: the Universal service manual, the current MAME
`universal/docastle.cpp` driver as a cross-check, and a decap reproduction of
the custom CF37201N sprite-support chip. Where MAME's driver and real-hardware
evidence disagree, the RTL follows the hardware evidence.

Accuracy work specific to this core:

- **Three real Z80 CPUs**, not one CPU emulating three — main, sub/sound, and
  sprite, each clocked at the true 4 MHz PCB rate, with the cycle-accurate
  main/sub WAIT handshake modeled rather than approximated with software
  synchronization.
- **A dumped, running sprite CPU.** The third Z80's ROM executes for real
  instead of being bypassed. The RTL implements both observed bus phases: the
  transfer of sprite staging RAM into its `0x8000` work doorway, and its
  `0xc000`–`0xc7ff` writes into the CF37201.
- **A decap-derived CF37201N model.** The custom sprite-support chip's
  register decode (A3 not decoded), X/Y counters, palette/flip latches, the
  exact two-phase DRAM address mux, serial inversion, field parity, and the
  measured 126-MCLK `/PL` interrupt cycle all follow the published decap
  reproduction of the TAL004 die, not a black-box behavioral guess.
- **Real CRTC behaviour.** The HD6845 model exposes writable R0–R15 timing,
  start address, memory/raster address generation, sync widths, display skew,
  and cursor shape/blink, with frame-shadowed register writes so an
  in-progress programming burst cannot commit a broken timing mode
  mid-frame — a failure mode the schematic's own CURSOR-interrupt wiring can
  otherwise trigger.
- **True PCB raster and pixel clock.** 312 x 264 total raster, 240 x 192
  visible, HD6845S at 9.828 MHz / 16, pixel clock 9.828 MHz / 2, giving the
  authentic ~59.659 Hz refresh (selectable in the OSD against a legacy
  fixed-rate profile for display compatibility).
- **The main-board watchdog** and correct tile/sprite priority encoding
  (bit 3 of each 4bpp pen as a priority/control bit, the two-pass
  transparency/mask behaviour of sprite pens 8–14 versus the pen-15 mask), and
  the documented colour-PROM addressing and RGB resistor weights.
- **Four independent SN76489A PSGs** with real READY-driven wait states
  instead of a fire-and-forget write, and Soccer's MSM5205 ADPCM channel at
  its verified clock and 4-bit mode.

An optional `PCB support` OSD mode goes further, enabling the CF37201's decap
model in place of the proven direct sprite renderer, and `PCB audio stage`
adds an approximation of the service-manual's AC-coupled output stage and
speaker roll-off. Both are deterministic, regression-tested against MAME
frame-by-frame across all nine sets, but — like the rest of this core — have
not yet been confirmed against a physical Do's Castle PCB, since no board has
been available during development. The direct renderer remains the default
until that comparison exists.

## ROMs and MRAs

Place the required MAME ROM archives for the sets above next to their MRA in
`_Arcade/`. ROM data is not distributed with this repository.

This repository is source-only: it contains no ROMs, no compiled RBF/SOF
build products beyond the released binary, and no Quartus compilation
databases, Verilator build products, or captured MAME/simulation traces.

Every MRA builds the same index-0 ROM stream:

| Offset | Size | Region |
|---:|---:|---|
| 00000 | 10000 | Main Z80 logical address space |
| 10000 | 04000 | Sub/sound Z80 |
| 14000 | 00200 | Sprite/protection Z80 |
| 14200 | 04000 | Tiles |
| 18200 | 20000 | Sprites |
| 38200 | 10000 | Soccer ADPCM or zero fill |
| 48200 | 00200 | Color PROM |

Total: 0x48400 bytes. ROM index 1 supplies the stable game ID.

## Releases

Prebuilt cores are in [`releases/`](releases/):

- `Arcade-DoCastle_YYYYMMDD.rbf` — the core, named per the standard
  MiSTer release convention.
- One `.mra` per supported game, each pointing at the same RBF.

Copy the RBF to `_Arcade/cores/` and the MRAs to `_Arcade/` on the MiSTer SD
card.

## Credits

This core combines the following third-party IP, each retained under its
original license (see `rtl/THIRD_PARTY.md` for full detail):

- **[T80](https://opencores.org/projects/t80)** Z80 CPU core — OpenCores T80,
  Daniel Wallner et al., MiSTer packaging by Sorgelig
  (`rtl/t80/`).
- **[JT89](https://github.com/jotego/jt89)** SN76489A PSG core — Jose Tejada
  Gomez (jotego), GPL-3.0-or-later, with local SN76489A LFSR and register-6
  reset corrections checked against MAME (`rtl/jt89/`).
- **[JT5205](https://github.com/jotego/jt5205)** MSM5205 ADPCM core — Jose
  Tejada Gomez (jotego), GPL-3.0-or-later, pinned revision
  `cd3cb834764534c205b8e912b1bea26570a36f7d`, used by the Indoor Soccer and
  American Soccer profile (`rtl/jt5205/`).
- **[MiSTer-CRT-Adjust](https://github.com/rmonic79/MiSTer-CRT-Adjust)** —
  Umberto Parisi (`rmonic79`), GPL-3.0-or-later, pinned revision
  `9616f9295c807b95a9cd0961981ebf08dbbabf08`, providing the OSD's H-Size,
  H-Position, and V-Shift controls (`rtl/crt_adjust.sv`).
- **[Arcade-MrDo_MiSTer](https://github.com/MiSTer-devel/Arcade-MrDo_MiSTer)**
  — Darren Olafson, GPL-2.0-or-later, consulted for MiSTer conventions and
  common-IP comparison; the Castle board logic in `rtl/docastle_*.sv` is an
  independent implementation from the service manual and the MAME driver.
- **[SiliconRE CF37201N](https://github.com/furrtek/SiliconRE/tree/master/Misc/CF37201N)**
  decap reproduction — furrtek, GPL-2.0, pinned revision
  `7c94fad788c33ff696ad7f07703b1dc303e3230c`, consulted as hardware evidence
  for the CF37201 register decode, counters, and timing. Its RTL was not
  copied; `rtl/docastle_cf37201.sv` is an independent synchronous model
  derived from the published decap observations, pinout, and schematic.
- **MiSTer framework** (`sys/`) — the standard
  [MiSTer-devel](https://github.com/MiSTer-devel) framework, unmodified
  except for the game PLL's generated output frequencies.
- **[MAME](https://www.mamedev.org/)** `universal/docastle.cpp` — used
  throughout as the reference behavioral model and differential-testing
  target, per [MAME's non-commercial license](https://github.com/mamedev/mame/blob/master/LICENSE.md).

## Build status

Built with Quartus Prime 17.0.2 Lite (Build 602) targeting the DE10-Nano's
Cyclone V 5CSEBA6U23. The released binary uses 13,551/41,910 ALMs (32%),
2,914,931/5,662,720 block-memory bits (51%), 370/553 RAM blocks (67%), and
41/112 DSP blocks (37%). Worst setup slack is +0.151 ns, worst hold slack is
+0.247 ns, worst recovery slack is +3.684 ns, worst removal slack is
+0.792 ns, worst minimum-pulse-width slack is +1.122 ns, and total negative
slack is zero in every reported domain.

`releases/Arcade-DoCastle_20260802.rbf` is 3,530,804 bytes, SHA-256
`68680AD9A042F9F4AE053E47815296B083203025ED41722A8705EFB8EFDAC44F`.

This core has completed deterministic Verilator-vs-MAME regressions across
all nine sets but has not yet been exercised on a physical Do's Castle PCB, as
no board has been available during development.

## License

GPL-3.0. See [LICENSE](LICENSE). Third-party components retain their own
licenses as noted in [Credits](#credits) and `rtl/THIRD_PARTY.md`.
