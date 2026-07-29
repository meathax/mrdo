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

The 8301 sprite CPU runs its dumped ROM. Its external `8000`/`c000` doorways
remain no-op just as in current MAME because the exact custom sprite-doorway
protocol is not yet documented; main-CPU sprite writes feed the renderer
directly. This limitation is isolated and observable for later schematic or
logic-analyser refinement.

## Video priority

Tiles and sprites are packed 4bpp. Bit 3 is a priority/control bit rather than
a palette address bit. Tile pens 8-15 form the foreground pass. Sprite pens
8-14 are visible, pen 15 is an invisible mask that blocks lower-priority
sprites, and pens 0-7 are transparent. The line renderer implements the exact
two-pass effect expressed by MAME's `prio_transmask` calls.

The colour PROM address is `{colour[4:0], pen[2:0]}`. RGB weights match MAME:
red/green `0x23,0x4b,0x91`; blue `0x52,0xad`.

## Open questions to validate

- Exact 8301/custom-sprite-chip doorway semantics beyond MAME's bypass.
- CRTC cursor-derived main/sprite interrupt detail called out by MAME TODO;
  the programmed CRTC register values and resulting raster/interrupt positions
  have been captured directly from a deterministic MAME run.
- Board-level analogue audio filtering and amplifier response.
- Pixel-clock correction from 4.9152 MHz to the nominal 4.914 MHz if a
  dedicated fractional PLL profile proves worthwhile on hardware.
