# Mr. Do's Castle MiSTer core audit

Audit date: 2026-07-29. Target set: MAME `docastle`, Universal 1983.

## Deterministic functional verification

The ROM archive was combined according to the MRA and exercised for 302 video
frames with all three Z80s and all four SN76489A-compatible PSGs active. The
safe Verilator run accepted a coin, started a game, produced 46,080 active
pixels on every 240 x 192 frame, and reported no stuck CPU wait or PSG READY
condition. The final frame remained byte-identical across the line-buffer and
video-RAM resource optimisations.

| Check | Result |
|---|---:|
| Combined ROM size | 99,328 bytes (`0x18400`) |
| Combined ROM SHA-1 | `5f97a5aeac0afbe36974eeeb7395a896d0ef229c` |
| Active raster | 240 x 192 at about 59.659 Hz, ROT270 |
| Title comparison with MAME | 91.08% pixel-exact; mean channel error 1.04/255 |
| Gameplay comparison with MAME | 68.164% pixel-exact; mean channel error 3.650/255 |
| Core audio | peak -17.503 dBFS; RMS -26.749 dBFS |
| MAME audio | peak -17.533 dBFS; RMS -28.056 dBFS |

The screenshot percentages are deliberately conservative direct-frame
comparisons. Title timing is closely aligned. Gameplay begins after independent
emulated input/video scheduling and therefore compares different animation
phases; visual inspection confirms matching map, colours, sprite geometry, and
priority/masking. Spectral inspection shows the same musical sequencing. The
FPGA output retains stronger square-wave harmonics because it does not model
MAME's host-rate audio filtering.

## CRTC evidence

A Lua trace captured the running MAME CRTC registers as
`26 20 22 62 1f 08 18 1c 00 07 00 00 00 80 00 82`. The RTL implements the
resulting 312 x 264 raw raster, 240 x 192 visible window, raw horizontal sync at
x=272 for 16 pixels, and vertical sync at line 224 for six lines.

## Quartus 17.0.2 Lite

The final source uses true dual-port M10K memories for tile/colour RAM and four
128 x 10 MLAB sprite line-buffer banks. This reduced the design from 20,355 to
about 13,106 ALMs while leaving deterministic video output unchanged.

| Fast Fit seed | HDMI setup slack | Game-core setup slack |
|---:|---:|---:|
| 1 | -0.776 ns | +4.427 ns |
| 2 | -0.175 ns | +4.903 ns |
| 3 | -0.337 ns | +3.958 ns |
| 4 | -3.291 ns | +4.377 ns |
| 5 | -0.105 ns | +4.539 ns |
| 6 | -0.134 ns | +4.433 ns |
| 7 | -0.718 ns | +4.199 ns |
| 8 | -0.459 ns | +4.165 ns |
| 9 | -0.791 ns | +4.512 ns |
| 10 | -0.406 ns | +4.278 ns |
| 11 | -0.136 ns | +4.031 ns |
| 12 | -0.692 ns | +4.440 ns |
| 13 | -0.752 ns | +3.817 ns |
| 14 | -1.944 ns | +4.312 ns |
| 15 | -1.783 ns | +4.812 ns |
| 16 | -0.592 ns | +5.443 ns |
| 17 | -0.461 ns | +5.049 ns |
| 18 | -0.368 ns | +4.333 ns |
| 19 | -0.883 ns | +4.806 ns |
| 20 | -0.104 ns | +4.822 ns |
| 21 | -0.513 ns | +4.569 ns |
| 22 | -0.111 ns | +5.031 ns |
| 23 | -0.928 ns | +4.548 ns |
| 24 | -0.007 ns | +4.810 ns |
| 25 | -0.118 ns | +4.991 ns |
| 26 | -1.668 ns | +4.571 ns |
| 27 | -0.460 ns | +4.682 ns |
| 28 | -0.204 ns | +4.350 ns |
| 29 | -0.515 ns | +4.579 ns |
| 30 | -0.108 ns | +4.322 ns |
| 31 | -1.336 ns | +4.113 ns |
| 32 | -0.437 ns | +4.683 ns |
| 33 | -0.159 ns | +3.915 ns |
| 34 | -0.303 ns | +4.092 ns |
| 35 | -0.283 ns | +4.452 ns |
| 36 | -0.184 ns | +4.000 ns |
| 37 | -0.616 ns | +4.831 ns |
| 38 | -2.356 ns | +4.284 ns |
| 39 | -0.817 ns | +4.537 ns |
| 40 | -0.212 ns | +4.829 ns |
| 41 | -0.326 ns | +4.800 ns |
| 42 | -0.888 ns | +4.391 ns |
| 43 | -0.424 ns | +5.390 ns |
| 44 | -0.212 ns | +4.222 ns |
| 45 | -0.453 ns | +4.413 ns |
| 46 | -0.190 ns | +4.801 ns |
| 47 | -0.866 ns | +4.229 ns |
| 48 | -0.229 ns | +4.911 ns |
| 49 | -0.860 ns | +4.310 ns |
| 50 | -1.254 ns | +4.366 ns |
| 51 | -0.961 ns | +3.452 ns |

The best unmodified Fast Fit result through seed 51 is seed 24 at -0.007 ns HDMI setup
slack and -0.013 ns TNS; no programming file from this sweep has been promoted.
Detailed timing inspection identified the stock scaler's horizontal terminal-count
test as the failing path: a 12-bit incrementer fed a comparator and then the
vertical-pipeline enables. The scaler now registers `htotal-1` and `vtotal-1`
and compares the counters directly, preserving the same wrap points while
removing the serial add/compare path. The first post-optimization build reuses
seed 24 so its placement can be compared with the earlier near-pass. That build
measured -0.803 ns HDMI setup slack and +4.417 ns game-core setup slack. A
post-optimization seed sweep follows because the netlist and its critical
endpoints have changed:

| Optimized seed | HDMI setup slack | Game-core setup slack |
|---:|---:|---:|
| 24 | -0.803 ns | +4.417 ns |
| 1 | -0.795 ns | +4.208 ns |

The optimized seed-1 critical path moved to the adaptive polyphase luminance
calculation. Its exact `max(R,G,B)` operation was two comparisons in series.
The first `max(R,G)` comparison is now performed in the preceding registered
pixel-selection stage and the existing luminance stage compares that result
with blue. This preserves the same value and cycle alignment while splitting
the comparator chain across two clocks.

With both scaler refactors applied, the final placement sweep produced:

| Final-netlist seed | HDMI setup slack | HDMI TNS | Game-core setup slack |
|---:|---:|---:|---:|
| 1 | -0.188 ns | -0.329 ns | +4.006 ns |
| 2 | -0.488 ns | -0.488 ns | +4.901 ns |
| 3 | -0.216 ns | -0.216 ns | +4.541 ns |
| 4 | **+0.289 ns** | **0.000 ns** | **+4.353 ns** |

Final-netlist seed 4 passes every reported setup domain. Its worst hold slack
is +0.253 ns, worst recovery slack +3.563 ns, worst removal slack +0.936 ns,
and worst minimum-pulse-width slack +1.122 ns. The build uses 13,126 of 41,910
ALMs (31%), 19,093 registers, 1,317,425 of 5,662,720 block-memory bits (23%),
and 34 of 112 DSP blocks (30%).

The timing-clean output was promoted as `releases/DoCastle_20260729.rbf`:

- Size: 2,982,792 bytes
- SHA-256: `2E7828E8BD009B0DA27AABA9233FAF61E9A82B13508FB86122A87E2540F471E1`
- Quartus policy: six workers, Fast Fit, normal router optimisation, physical
  synthesis off, Smart Recompile on, saved compilation databases, seed 4

A post-timing safe Verilator regression ran the existing model through frame
302. It again produced 46,080 active pixels per frame, active main/sub/sprite
CPUs, an unstalled main wait input, and all four PSG ready signals asserted.
The new gameplay PPM and WAV are byte-identical to the pre-timing captures:

- Gameplay SHA-256: `75197EB6504E31B6CA0362CE27C85D6723C5153F678B4A67C53B3DAAAC064534`
- Audio SHA-256: `684367C3BCB7D8852F94F4AE484C39C17839B0304348D1BF2E5B2FF81F763CF7`

## Hardware deployment status

The timing-clean universal RBF and all nine MRAs have been exercised through
the normal MiSTer deployment layout. Host addresses, credentials, local paths,
and compiled bitstreams are intentionally not included in this source-only
repository. Deploy the RBF to `_Arcade/cores/` and the MRAs to `_Arcade/` by
SSH/SMB, a mounted SD card, or another standard MiSTer transfer method.

## Known fidelity boundary

The dumped 8301 sprite CPU executes, while its custom external doorway remains
a no-op matching current MAME. Board-level analogue filtering is not emulated.
These are documented fidelity limits rather than untested logic paths.
