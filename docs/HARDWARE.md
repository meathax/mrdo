# Hardware notes and implementation evidence

## Primary sources

1. Universal, *Mr. Do vs. Unicorns / Mr. Do's Castle Service Manual*, 1983:
   https://www.gamesdatabase.org/Media/SYSTEM/Arcade/Manual/formated/Mr._Do_vs._Unicorns_-_1983_-_Universal.pdf
2. Current MAME `universal/docastle.cpp`, locally at
   `D:/Arcade/AI/MAMESOURCE/mame/src/mame/universal/docastle.cpp`.
3. MAME upstream driver:
   https://github.com/mamedev/mame/blob/master/src/mame/universal/docastle.cpp
4. MiSTer Mr. Do! reference core:
   https://github.com/MiSTer-devel/Arcade-MrDo_MiSTer

## Clock and raster

- Main, sub and sprite CPUs: Z80 at 4 MHz.
- Four SN76489A PSGs: 4 MHz.
- CRTC: HD6845S at 9.828 MHz / 16, character width 8.
- Pixel clock: 9.828 MHz / 2 = 4.914 MHz.
- Raster: 312 x 264 total; visible MAME bitmap x=8..247, y=0..191.
- Result: 240 x 192 at about 59.659 Hz, rotated CCW in the cabinet.

The MiSTer PLL generates 49.152 MHz for the raster domain and 24.576 MHz for
audio. `/10` gives 4.9152 MHz, a 0.0244% pixel-clock delta; a rational 125/1536
clock enable gives exactly 4.000 MHz for the CPUs and PSGs.

## CPU maps

The HDL maps the current MAME driver directly. Main ROM is `0000-7fff`, work
RAM `8000-97ff`, sprite writes `9800-99ff`, synchronized latch `a000-a7ff`,
tile/colour RAM `b000-bfff` with the documented mirrors, and sub-NMI trigger
`e000`. The sub CPU maps ROM `0000-3fff`, RAM `8000-87ff`, the latch at
`a000-a7ff`, input mux at `c000-c007/c080-c087`, and PSG writes at
`e000/e400/e800/ec00`.

The 8301 sprite CPU runs its dumped ROM instead of being bypassed. The RTL
implements both observed transfer phases: main sprite staging RAM to its
`0x8000` work doorway, then `0xc000-0xc7ff` writes into the CF37201. Disassembly
and simulation show `0xc432` changing from `0x20` to `0x00`; that falling bit
arms the custom chip's `/PL` interval, whose interrupt is acknowledged by the
third Z80 and re-armed while enabled. Only real bus writes feed this path.

The synchronous CF37201 model follows the available TAL004 decap reproduction:
three decoded registers (A3 is not decoded), register-1 staging, X/Y counters,
palette/flip latches, the exact two-phase DRAM address mux, serial inversion,
field parity, and the measured 126-MCLK `/PL` cycle. Normal PCB support retains
the visually proven sprite renderer; the optional full 64K two-field renderer
is deliberately experimental because it still misses part of the title logo.

The HD6845 model has writable R0-R15 timing, start address, memory/raster
address generation, sync widths, display skew, cursor shape, and cursor blink.
Writes are frame-shadowed, and incomplete all-zero programming bursts are not
committed as a dead timing mode. VSYNC remains the production interrupt source:
with CURSOR selected, Do! Run Run deliberately clears all CRTC registers and
does not recover in simulation, so the schematic ambiguity remains open.

## Video priority

Tiles and sprites are packed 4bpp. Bit 3 is a priority/control bit rather than
a palette address bit. Tile pens 8-15 form the foreground pass. Sprite pens
8-14 are visible, pen 15 is an invisible mask that blocks lower-priority
sprites, and pens 0-7 are transparent. The line renderer implements the exact
two-pass effect expressed by MAME's `prio_transmask` calls.

The colour PROM address is `{colour[4:0], pen[2:0]}`. RGB weights match MAME:
red/green `0x23,0x4b,0x91`; blue `0x52,0xad`.

## Open questions to validate

- Physical validation of the decap-derived CF37201 timing and field output.
- Why the schematic CURSOR-derived interrupt conflicts with the game's later
  all-zero CRTC programming burst; VSYNC is the validated release behavior.
- The `dorunrun2` 12-round sequence, pending the clone ROM archive and PCB.
- Board-level analogue audio filtering and amplifier response.
- Pixel-clock correction from 4.9152 MHz to the nominal 4.914 MHz if a
  dedicated fractional PLL profile proves worthwhile on hardware.
