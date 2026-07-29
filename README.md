# Universal Do! Castle Hardware for MiSTer

One runtime-selectable FPGA core for the Universal Do's Castle board family.
The release target is **Universal_DoCastle.rbf**, selected by a separate MRA
for each game.

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
handshake, TMS1025 input pipeline, four SN76489A PSGs with READY-driven wait,
live board-relevant HD6845 registers and raster outputs, profile-specific CPU
maps and tile priority, standard and Soccer sprite formats, Soccer dual-stick
inputs, and Soccer MSM5205 ADPCM through a pinned JT5205 implementation. It
also includes the main-board watchdog and a decap-informed synchronous model
of the third-CPU/CF37201 sprite doorway. The wrapper provides OSD-controlled
CRT H-Size, H-Position, and V-Shift through the pinned MiSTer-CRT-Adjust
core-side implementation, plus selectable normal or full H+V integer HDMI
scaling.

## PCB support options

The default remains the nine-game visually proven path. `PCB support` enables
the dumped third CPU's two real transfer phases, the decoded CF37201 registers,
the chip's 126-MCLK `/PL`/interrupt cycle, and the three-second watchdog while
retaining the proven renderer. The CF model now uses the decap-derived address,
counter, flip, palette, and field-select equations. This mode completed
software regressions for all nine sets and a 361-frame Do! Run Run timing run.

`PCB audio stage` adds a 48 kHz approximation of the service-manual output
coupling and speaker roll-off. `Experimental CF framebuffer` selects the full
two-field 64K renderer driven only by the real third-CPU/CF stream; it remains
opt-in because the central title sprite is still missing in comparison with
the proven renderer. `Experimental IRQ` compares the schematic CURSOR source
with validated VSYNC behavior. CURSOR mode is not a release default: the game
later clears every CRTC register and stalls, while VSYNC completes cleanly.

## ROMs and MRAs

Place the nine named ZIPs beside this README. ROM data is not distributed.

This public repository is source-only. It intentionally excludes ROMs,
compiled RBF/SOF files, Quartus compilation databases, Verilator products,
MAME captures, traces, and local configuration. Generated MRA descriptors are
included because they contain the per-game MiSTer metadata and ROM layout;
their hashes can be regenerated after supplying the required ROM archives.

Every MRA builds the same index-0 stream:

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

The canonical source is scripts/romsets.json, generated from the audited MAME
driver. To validate all archives, build all fixed images, regenerate the nine
MRAs, and validate their offsets and hashes:

    powershell -ExecutionPolicy Bypass -File verif/prepare_rom.ps1 -SetName all
    powershell -ExecutionPolicy Bypass -File scripts/generate_mras.ps1
    powershell -ExecutionPolicy Bypass -File scripts/validate_mras.ps1

## Verification

The Verilated model is built once and reused. All model builds and runs must
use the machine-safe launchers described in verif/README.md. MAME reference
captures are generated for every set by verif/run_mame_capture.ps1.

The regression runner accepts `-Pcb`, `-PcbAudio`, `-PcbFramebuffer`, and
`-CursorIrq` for the matching OSD paths. `verif/check_dorunrun_timing.ps1`
performs the long rational-cadence, watchdog, third-CPU-copy, and CF-event
check.

## Quartus status

The enhanced shared Universal_DoCastle RBF was built successfully with Quartus
17.0.2 Lite on 2026-07-29. The seed-4 Fast Fit uses 17,572/41,910 ALMs,
4,119,089/5,662,720 block-memory bits, 517/553 RAM blocks, and 41/112 DSP
blocks. Worst setup slack is +0.259 ns, worst hold slack is +0.251 ns, worst
recovery slack is +4.223 ns, worst removal slack is +0.747 ns, worst minimum
pulse-width slack is +1.122 ns, and TNS is zero in every reported domain.
The generated RBF is 3,973,880 bytes with SHA-256
`7552B2EFAB29DF148B5AC09C0FA7F317CE453BB52CA237F8BCB4B65BE785A69B`.
All nine generated MRAs select this same RBF; the historical single-game image
is isolated under `releases/legacy`.

See docs/UNIVERSAL_DOCASTLE_PLAN.md, rtl/THIRD_PARTY.md, and LICENSE.
