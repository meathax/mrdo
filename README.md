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
CRTC-derived video timing, profile-specific CPU maps and tile priority,
standard and Soccer sprite formats, Soccer dual-stick inputs, and Soccer
MSM5205 ADPCM through a pinned JT5205 implementation.

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

## Quartus status

The single shared Universal_DoCastle RBF was built successfully with Quartus
17.0.2 on 2026-07-29, but the compiled file is not distributed in this source
repository. The fitter used 13,499/41,910 ALMs and
2,890,289/5,662,720 memory bits. Worst setup slack is +0.002 ns, worst hold
slack is +0.248 ns, and reported TNS is zero. All nine generated MRAs select
this same RBF; the historical single-game image is isolated under
releases/legacy.

See docs/UNIVERSAL_DOCASTLE_PLAN.md, rtl/THIRD_PARTY.md, and LICENSE.
