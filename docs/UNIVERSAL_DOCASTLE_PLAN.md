# Universal Do! Castle Hardware MiSTer Core — Implementation Plan

**Plan status:** RTL/MRA implementation and nine-game software verification complete; corrected Soccer ADPCM gain resimulated successfully; one Universal_DoCastle RBF built with positive slack in every analyzed timing domain; MiSTer deployment/on-device audit not performed in the current build-only step  
**Target FPGA file:** Universal_DoCastle.rbf  
**Target delivery:** One shared RBF and one MRA for each supported game  
**Primary accuracy oracle:** Local current MAME source plus schematics, manuals, PCB evidence, decap data, and controlled emulator comparisons

## 1. Outcome and scope

The project will be converted from a single-game Mr. Do's Castle core into one runtime-selectable core for the Universal Do's Castle hardware family. Each MRA will load a fixed-format ROM image and a stable one-byte game ID. The FPGA will decode that ID into one of three hardware profiles rather than maintaining separate builds.

The first complete release must boot and run all nine supplied sets:

| ID | ZIP / MAME set | Display name | Hardware profile | Native rotation | Special requirements |
|---:|---|---|---|---|---|
| 00 | docastle.zip / docastle | Mr. Do's Castle | Castle | ROT270 | Castle memory map and high-pen tile priority |
| 01 | douni.zip / douni | Mr. Do! vs. Unicorns | Castle | ROT270 | Alternate program, object graphics, and color PROM |
| 02 | dorunrun.zip / dorunrun | Do! Run Run | Run Run | ROT0 | Run Run maps and low-pen tile priority |
| 03 | dowild.zip / dowild | Mr. Do's Wild Ride | Run Run | ROT0 | Run Run profile |
| 04 | jjack.zip / jjack | Jumping Jack | Run Run | ROT270 | Run Run profile with vertical MRA orientation |
| 05 | kickridr.zip / kickridr | Kick Rider | Run Run | ROT0 | Run Run profile |
| 06 | spiero.zip / spiero | Super Pierrot | Run Run | ROT0 | Run Run profile |
| 07 | idsoccer.zip / idsoccer | Indoor Soccer | Soccer | ROT0 | Dual-stick inputs, extended sprites, MSM5205 ADPCM |
| 08 | asoccer.zip / asoccer | American Soccer | Soccer | ROT0 | Soccer hardware, game-specific controls and DIP switches |

ROM files remain user-supplied and will not be redistributed.

### Deferred while this plan is being implemented

- No MiSTer SSH, Misterclaw, RBF deployment, or physical screenshot audit until the user lifts the current “do not use MiSTer” direction.
- No Quartus compilation until all nine profiles pass the required software simulation gates.
- The existing Mr. Do's Castle release stays intact until the universal replacement is demonstrably better.

## 2. Key architectural decisions

1. **One RBF, three hardware profiles, nine stable game IDs.** The ID is retained independently of reset and decoded centrally.
2. **One fixed ROM ABI.** Every MRA produces the same 0x48400-byte index-0 stream. Sparse CPU and ADPCM holes are explicitly filled, so RTL addressing remains natural and does not depend on load order or game-specific packed offsets.
3. **MAME-equivalent functionality first.** Extend the current direct sprite renderer to boot every game before replacing it with a third-Z80/CF37201 framebuffer implementation.
4. **Hardware fidelity as a gated second milestone.** The CF37201 decap is a valuable hardware oracle, but its reproduction RTL is not a safe drop-in and its licensing must be resolved before any direct reuse.
5. **Build the Verilated model once, run all profiles serially.** Runtime ROM, game ID, input script, and capture arguments must not trigger redundant rebuilds.
6. **MRA owns native orientation and game-specific settings.** The core still exposes MiSTer's normal user rotation controls, but each MRA starts with the correct cabinet orientation and DIP layout.
7. **No silent defaults.** Unknown game IDs must hold the machine in reset and expose a diagnostic condition rather than accidentally selecting Castle behavior.

## 3. Research baseline and source policy

### 3.1 Authoritative local MAME baseline

The implementation baseline is:

- D:/Arcade/AI/MAMESOURCE/mame/src/mame/universal/docastle.cpp
- Local MAME revision: affe701f9210d003d2cc5eff311f94053afa679b
- Snapshot date observed during audit: 2026-07-21
- Driver license: BSD-3-Clause

Important areas in that source:

| Subject | Approximate lines |
|---|---:|
| Hardware notes, timing concerns, and TODOs | 116–158 |
| Machine/profile class definitions | 186–300 |
| Tile/sprite priority | 353–364 |
| Color PROM conversion | 384–428 |
| TMS1025 input and flip handling | 444–465 |
| Sprite formats and composition | 468–554 |
| Main/sub latch and WAIT synchronization | 586–653 |
| Soccer ADPCM control | 670–715 |
| CPU maps | 724–802 |
| Inputs and DIP switches | 810–1058 |
| Clocks and machine configurations | 1066–1157 |
| ROM declarations | 1166–1636 |
| Game registrations and rotations | 1647–1666 |

Related local device references:

- D:/Arcade/AI/MAMESOURCE/mame/src/devices/machine/tms1024.cpp
- D:/Arcade/AI/MAMESOURCE/mame/src/devices/machine/tms1024.h
- D:/Arcade/AI/MAMESOURCE/mame/src/devices/sound/sn76496.cpp
- D:/Arcade/AI/MAMESOURCE/mame/src/devices/sound/msm5205.h

All behavior ported from MAME must retain BSD attribution in the source tree. The ROM declarations are the canonical filenames, addresses, sizes, CRC32 values, and SHA-1 values for MRA generation.

### 3.2 Reusable source and license gate

| Reference | Use | License / rule |
|---|---|---|
| Current local T80 | Keep as the Z80 implementation unless testing identifies a core bug | Preserve its existing notices and audit provenance before release |
| Existing local JT89 | Four SN76489A-compatible PSGs | GPL-3.0-compatible with this project |
| Jotego JT5205 | Soccer MSM5205 implementation | GPL-3.0; pin a reviewed revision and preserve attribution |
| MAME docastle driver | Behavioral specification and comparison oracle | BSD-3-Clause; reuse with attribution |
| Furrtek SiliconRE CF37201N work | Decap, pinout, schematic, trace, and behavioral oracle | Published under GPL-2.0; direct compatibility with this GPL-3.0-only project is not established |
| FinalBurn Neo driver | Secondary behavioral cross-check only | Non-commercial restriction; do not copy code |
| Arcade-MrDo_MiSTer | MiSTer wrapper/common-IP patterns only | Earlier Mr. Do hardware, not this board family |

No exact public MiSTer, Verilog, VHDL, or Jotego core for this hardware family was found. This project therefore needs a genuine three-profile extension rather than a simple transplant.

### 3.3 CF37201N custom-chip evidence

Furrtek's SiliconRE repository contains a decap-derived pinout, transistor/gate trace, schematic, and reproduction Verilog for the CF37201N custom sprite device. It identifies a double-buffered framebuffer architecture and a framebuffer address formed from frame parity, eight Y bits, and seven pixel-pair X bits.

The published reproduction contains explicit uncertainty and asynchronous latch-style constructs. The release plan is therefore:

1. Use its documentation as an external hardware oracle.
2. Do not copy the reproduction RTL until GPL compatibility or separate permission is confirmed.
3. If permission is unavailable, write an independent synchronous implementation from observable hardware behavior and schematics, documenting the separation.
4. Keep the known-good MAME-style sprite path selectable in verification until the custom-chip path is proven equivalent or more accurate.

### 3.4 Supplied ROM archive inventory

All requested archives are present. These SHA-1 values identify the supplied ZIP containers; the future manifest tool must additionally validate every contained ROM against MAME's CRC32 and SHA-1:

| Archive | ZIP SHA-1 |
|---|---|
| docastle.zip | 95263c40d975f8db36a56d156abd9dfcbf25c17c |
| douni.zip | 4fffbc822112699d9580bd9f4e3b1c106a8a3747 |
| dorunrun.zip | 9ef32a2a7bcf18fb663bb2f48ae322834d6273c6 |
| dowild.zip | 89db8f372920e5eb1404cdf5ce12347c5738affc |
| jjack.zip | 64a6b1234606aedbfabf868d7c677c86d01aba2d |
| kickridr.zip | 4262199a05e0e957af2810c849a13d7a48245459 |
| spiero.zip | 5c60cbd24285fedc1b91ae7f443001274654a831 |
| idsoccer.zip | 0725bc6bcbc4a57d26e9a6a05ebaf5ed52f7c1ed |
| asoccer.zip | 6c9b72c8a0c083529e7d0c62415a6bc7358f2e76 |

## 4. Hardware profiles to implement

| Feature | Castle | Run Run | Soccer |
|---|---|---|---|
| Games | docastle, douni | dorunrun, dowild, jjack, kickridr, spiero | idsoccer, asoccer |
| Main CPU map | Castle | Run Run | Soccer |
| Sub CPU map | Castle | Run Run | Castle |
| Foreground tile pens | 8–15 | 0–7 | 0–7 |
| Sprite code | 8-bit | 8-bit | 10-bit |
| Sprite palette | 5-bit | 5-bit | 4-bit |
| Local sprite Y flip | Yes | Yes | No; attribute bits extend code |
| Extra input mux port | No | No | JOYS2 |
| ADPCM | No | No | MSM5205, four-bit S48 |

### 4.1 Clocks and raster

The shared timing target is:

- Three Z80s at 4.000 MHz.
- Four SN76489A PSGs at 4.000 MHz.
- HD6845S character clock: 9.828 MHz / 16 = 614.25 kHz.
- Pixel clock: 9.828 MHz / 2 = 4.914 MHz.
- Raw raster: 312 × 264.
- Visible raster: X 8–247 and Y 0–191, giving 240 × 192.
- Nominal refresh: 59.6590909 Hz.

The current rational enables from 49.152 MHz are suitable in average frequency:

- Pixel enable: 49.152 MHz × 819 / 8192 = 4.914 MHz.
- CPU enable: 49.152 MHz × 125 / 1536 = 4.000 MHz.

They must be validated for phase, pulse width, and consumer assumptions rather than replaced casually.

MAME drives main IRQ and sprite NMI from VSYNC. Schematics indicate that one or both may be driven by the CRTC cursor output. The initial compatibility target is current MAME behavior; a later controlled cursor-versus-VSYNC comparison must use schematics, real-board evidence, attract timing, and game stability before changing production behavior.

### 4.2 CPU memory maps

**Castle main CPU**

| Range / address | Function |
|---|---|
| 0000–7fff | Program ROM |
| 8000–97ff | Work RAM |
| 9800–99ff | Sprite RAM writes |
| a000–a7ff | Main/sub communication latch |
| a800 | Watchdog strobe |
| b000–b3ff, mirrored at b800–bbff | Video RAM |
| b400–b7ff, mirrored at bc00–bfff | Color RAM |
| e000 | Pulse sub-CPU NMI |

**Run Run main CPU**

| Range / address | Function |
|---|---|
| 0000–1fff, 4000–9fff | Program ROM |
| 2000–37ff | Work RAM |
| 3800–39ff | Sprite RAM writes |
| a000–a7ff | Main/sub communication latch |
| a800 | Watchdog strobe |
| b000–b3ff | Video RAM, without Castle mirror |
| b400–b7ff | Color RAM, without Castle mirror |
| b800 | Pulse sub-CPU NMI |

**Soccer main CPU**

| Range / address | Function |
|---|---|
| 0000–3fff, 6000–9fff | Program ROM |
| 4000–57ff | Work RAM |
| 5800–59ff | Sprite RAM writes |
| a000–a7ff | Main/sub communication latch |
| a800 | Watchdog strobe |
| b000–b7ff with Castle-style mirrors | Video and color RAM |
| c000 | ADPCM control/status |
| e000 | Pulse sub-CPU NMI |

**Castle/Soccer sub CPU**

| Range | Function |
|---|---|
| 0000–3fff | Program ROM |
| 8000–87ff | RAM |
| a000–a7ff | Main/sub communication latch |
| c000/c080 | TMS1025 select/read path |
| e000/e400/e800/ec00 | Four PSG write ports |

**Run Run sub CPU**

| Range | Function |
|---|---|
| 0000–3fff | Program ROM |
| 8000–87ff | RAM |
| a000/a400/a800/ac00 | Four PSG write ports |
| c000/c080 | TMS1025 select/read path |
| e000–e7ff | Main/sub communication latch |

**Sprite CPU**

| Range | Function |
|---|---|
| 0000–00ff | Effective sprite CPU PROM; supplied 0x200 images have unused upper content |
| 4000–47ff | Sprite CPU RAM |
| 8000 | Main latch doorway, currently bypassed by MAME |
| c000–c7ff | CF37201 doorway, currently bypassed by MAME |

### 4.3 Main/sub synchronization

The main and sub Z80s exchange one bidirectional byte latch, not shared RAM:

- Main access asserts WAIT.
- A corresponding sub access clears WAIT.
- T80 retry behavior, byte direction, and 4 MHz cycle placement must match the board.
- LDIR-based transfers and TMS1025 reads make approximations visibly unstable.
- A timeout or “helpful” auto-release must not be introduced.

MAME's November 2024 communication fixes are required study material. Verification must log each latch write/read, WAIT assertion/release, PC, bus cycle type, and emulated timestamp.

### 4.4 TMS1025 input mux behavior

Two devices provide the low and high nibbles of each active-low input byte.

| Select | Source |
|---:|---|
| 1 | DSW2 |
| 2 | DSW1 |
| 3 | JOYS |
| 4 | JOYS2, Soccer only |
| 5 | BUTTONS |
| 7 | SYSTEM |

A read returns the previously selected input and then latches the new selector. Select zero is high impedance and retains the previous nibble. Address bit A7 controls global flip. Reads update selector and flip; writes update flip only. The current RTL recently corrected this pipeline and it must receive explicit regression tests before other refactoring.

### 4.5 Video behavior

- Tile map: 32 × 32 cells, 8 × 8 pixels, with MAME's vertical offset of -32.
- Tile code: video byte plus 0x100 when color bit 5 is set.
- Tile palette: color bits 0–4.
- Graphics packing: 4bpp, high nibble first.
- Sprite RAM: 0x200 bytes, 128 four-byte entries, processed in reverse order.
- Standard attributes: Y, X, attributes, code; attribute 7 flips Y, 6 flips X, and 0–4 select palette.
- Soccer attributes: bit 7 adds code 0x200, bit 4 adds code 0x100, bit 6 flips X, and bits 0–3 select palette. There is no local Y-flip bit.
- Global flip transforms X to 240-X and Y to 176-Y and inverts applicable flip flags.
- Castle draws tile pens 8–15 in front of sprites.
- Run Run and Soccer draw tile pens 0–7 in front of sprites.
- Sprite pens 8–14 are visible; pen 15 is an invisible mask that blocks later sprites; pens 0–7 are transparent.
- PROM resistor weights are R/G 0x23, 0x4b, 0x91 and B 0x52, 0xad.
- Some 0x200 PROM dumps contain an unused/zero upper half; the fixed ABI preserves all 0x200 bytes while the palette consumes the defined lower entries.

The current two-pass line renderer should first be widened for 10-bit Soccer codes and profile-selectable priority. It must expose an overrun assertion proving that all 128 entries fit in the available blanking interval.

### 4.6 Audio behavior

All profiles use four equal-gain SN76489A devices. A low READY from any selected PSG must stall the sub Z80. At a 4 MHz PSG clock a write remains busy for approximately 8 microseconds, or 32 Z80 clocks; the JT89 mode and READY polarity/timing must be confirmed against MAME event logs.

Soccer additionally uses an MSM5205:

- Input clock: 384 kHz.
- Mode: S48, four-bit input, 8 kHz nibble request.
- Relative MAME gain: 0.40.
- C000 status: 0x80 while playing, otherwise zero.
- D7 falling edge stops and resets playback.
- D6 falling edge starts playback.
- Bits 1:0 choose a 0x4000-byte sample bank.
- Playback emits high nibble then low nibble for exactly 0x8000 nibbles.
- The 0x4000–0x7fff bank is physically unpopulated and must read as zero.
- If stop and start edges occur in one write, start wins.

JT5205 is the preferred implementation, with its revision pinned and verified at the effective 384 kHz timing.

## 5. Fixed ROM-loading ABI

Every game MRA will emit this exact index-0 layout:

| Index-0 range | Size | Region |
|---|---:|---|
| 00000–0ffff | 0x10000 | Main CPU logical address space |
| 10000–13fff | 0x04000 | Sub CPU ROM |
| 14000–141ff | 0x00200 | Sprite CPU PROM |
| 14200–181ff | 0x04000 | Tile graphics |
| 18200–381ff | 0x20000 | Sprite/object graphics |
| 38200–481ff | 0x10000 | Soccer ADPCM; zero-filled otherwise |
| 48200–483ff | 0x00200 | Color PROM |

Total index-0 length: **0x48400 bytes (295,936 bytes)**.

Reasons for choosing a fixed maximum layout:

- CPU ROMs retain their natural 16-bit addresses, including Run Run and Soccer holes.
- Soccer's empty ADPCM socket remains a real zero-filled hole.
- One ROM decoder works for every set.
- The index-0 length and hash are deterministic.
- Game selection never depends on which ioctl index finishes first.
- MRA repeat/fill elements create padding without adding files to the user's ZIP.

Each MRA also emits its one-byte ID through ROM index 1. Reset must cover downloads to both relevant indexes, and the profile ID must be latched before reset is released. A wrong length, unknown ID, or checksum failure on the host-side packer is fatal.

The exact RBF binding in every MRA is:

<rbf>Universal_DoCastle</rbf>

### 5.1 Per-set manifest order

The generated manifests will use these audited MAME regions and natural offsets:

| Set | Main CPU ROMs | Sub / sprite CPU | Tile / sprite graphics | ADPCM | PROM |
|---|---|---|---|---|---|
| docastle | 01p_a1.bin@0000, 01n_a2.bin@2000, 01l_a3.bin@4000, 01k_a4.bin@6000 | 07n_a0.bin / 01d.bin | 03a_a5.bin / 04m_a6.bin, 04l_a7.bin, 04j_a8.bin, 04h_a9.bin | zero | 09c.bin |
| douni | dorev1.bin@0000, dorev2.bin@2000, dorev3.bin@4000, dorev4.bin@6000 | dorev10.bin / 01d.bin | 03a_a5.bin / dorev6.bin, dorev7.bin, dorev8.bin, dorev9.bin | zero | dorevc9.bin |
| dorunrun | 2764.p1@0000, 2764.l1@4000, 2764.k1@6000, 2764.n1@8000 | 27128.p7 / bprom2.bin | 27128.a3 / 2764.m4, 2764.l4, 2764.j4, 2764.h4 | zero | dorunrun.clr |
| dowild | w1@0000, w3@4000, w4@6000, w2@8000 | w10 / 8300b-2 | w5 / w6, w7, w8, w9 | zero | dowild.clr |
| jjack | j1.bin@0000, j3.bin@4000, j4.bin@6000, j2.bin@8000 | j0.bin / bprom2.bin | j5.bin / j6.bin, j7.bin, j8.bin, j9.bin | zero | bprom1.bin |
| kickridr | k1@0000, k3@4000, k4@6000, k2@8000 | k10 / 8300b-2 | k5 / k6, k7, k8, k9 | zero | kickridr.clr |
| spiero | sp1.bin@0000, sp3.bin@4000, sp4.bin@6000, sp2.bin@8000 | 27128.p7 / bprom2.bin | sp5.bin / sp6.bin, sp7.bin, sp8.bin, sp9.bin | zero | bprom1.bin |
| idsoccer | id01@0000, id02@2000, id03@6000, id04@8000 | id10 / id_8p | id05 / id06, id07, id08, id09 | is1@0000, zero@4000, is3@8000, is4@c000 | id_3d.clr |
| asoccer | as1.e10@0000, as2.f10@2000, as3.h10@6000, as4.k10@8000 | as0.e2 / 200b.p8 | as5-2.e6 / as6.p3-2, as7.n3-2, as8.l3-2, as9.j3-2 | 1.ic1@0000, zero@4000, 3.ic3@8000, 4.ic4@c000 | 3-2d.d3-2 |

The manifest generator must store the expected length, CRC32, and SHA-1 for every listed file and must calculate the final stream's MD5/SHA-1 for the MRA and regression log.

## 6. Target RTL structure

The lowest-risk implementation is an incremental refactor of the working modules rather than a wholesale rewrite.

### 6.1 Top-level and profile decoder

Create:

- Universal_DoCastle.sv
- Universal_DoCastle.qpf
- Universal_DoCastle.qsf
- Universal_DoCastle.sdc
- rtl/docastle_profile.sv

Keep sys_top as the framework top-level. The profile decoder produces an immutable descriptor containing:

- Stable game ID.
- Main address-map selector.
- Sub address-map selector.
- Foreground tile-pen selector.
- Standard or Soccer sprite format.
- ADPCM-present flag.
- JOYS2-present flag.
- Native orientation metadata for diagnostics.
- Reserved per-game quirk bits for fixes that cannot safely be generalized.

The descriptor is loaded only while the core is held in reset. It is then distributed to the main CPU, sub CPU, video, input, audio, and verification instrumentation.

### 6.2 ROM and RAM

- Widen main ROM addressing to 16 bits.
- Widen object graphics addressing to 17 bits.
- Add a 16-bit ADPCM ROM address.
- Replace hard-coded packed offsets with the fixed ABI constants.
- Size main work RAM for the largest 0x1800-byte mapped window and decode it per profile.
- Retain independent video, color, sprite, sub, and sprite-CPU RAM behavior.
- Assert on every out-of-range ROM address during simulation.

### 6.3 CPU maps and interrupts

- Refactor rtl/docastle_main.sv into profile-selected decode without duplicating the Z80.
- Refactor rtl/docastle_sub.sv for Castle versus Run Run communication/PSG locations and JOYS2 selection.
- Preserve exact WAIT handshake behavior through the refactor.
- Keep current MAME-compatible VSYNC interrupts for initial bring-up.
- Upgrade the relevant HD6845 register/counter model, including MA, DE, HSYNC, VSYNC, cursor, and the MA6-derived sub IRQ.
- Add a verification-only selector for cursor-versus-VSYNC research before any production change.
- Decode the watchdog strobe but do not invent an unverified timeout period.

### 6.4 Video

- Add a profile-controlled foreground half.
- Widen the active sprite code and graphics address for Soccer.
- Implement Soccer's attribute interpretation and lack of local Y-flip.
- Preserve reverse sprite order, pen-15 masking, transparency, global flip, and PROM conversion.
- Add scanline renderer start/end/overrun counters.
- Add capture signals for tile-only, sprite-only, priority mask, palette index, and composed RGB.
- Keep the direct MAME-style renderer as the release path until a CF37201 replacement passes all comparisons.

### 6.5 Audio

- Preserve four JT89 instances and equal mix contribution.
- Verify and, if required, correct PSG READY wired-OR behavior and sub-CPU wait timing.
- Add rtl/docastle_adpcm.sv around a pinned JT5205 revision.
- Reproduce MAME's start/stop edge priority, bank selection, status bit, empty bank, nibble order, and length.
- Use sufficient signed headroom for four PSGs plus ADPCM; saturate only at the final output.
- Capture PSG register writes and ADPCM bank/nibble events in simulation.

### 6.6 Inputs and MRAs

- Keep inputs active low at the emulated board boundary.
- Implement all MAME DIP switches separately per game; do not use one generic table.
- Default non-Soccer sets to DSW1 DF / DSW2 FF.
- Default Soccer sets to DSW1 FF / DSW2 FF.
- Extend DoCastle.sv wiring to use the existing hps_io left and right analog joystick buses.
- Soccer mapping: D-pad/left analog is the left stick; right analog is the right stick.
- Provide a documented digital fallback using a face-button cluster for the right stick.
- Apply deadzone and hysteresis before converting analog direction to active-low digital inputs.
- Support American Soccer's single/dual-joystick DIP and its second-button player-change behavior.
- Put native rotation and game-specific button labels in each MRA.

## 7. Concrete file-change map

| File or area | Planned change |
|---|---|
| DoCastle.sv | Preserve as a compatibility reference; migrate wrapper behavior into Universal_DoCastle.sv |
| DoCastle.qpf/qsf/sdc | Create universal-named project/revision files; do not overwrite the old revision during bring-up |
| rtl/docastle_core.sv | Accept game ID/profile and connect widened ROM, JOYS2, and ADPCM paths |
| rtl/docastle_main.sv | Three selectable main maps and profile-sized RAM decode |
| rtl/docastle_sub.sv | Castle/Run Run sub maps, JOYS2, PSG READY verification, ADPCM control path |
| rtl/docastle_spritecpu.sv | Retain bypass initially; instrument doorway and prepare later CF37201 integration |
| rtl/docastle_video.sv | Runtime priority mode, Soccer attributes, wider object ROM, diagnostics |
| rtl/docastle_rom.sv | Fixed 0x48400 ABI, widened addresses, ADPCM region |
| rtl/docastle_profile.sv | New central game-ID descriptor |
| rtl/docastle_adpcm.sv | New Soccer sample controller and JT5205 wrapper |
| verif/prepare_rom.ps1 | Replace single-set list with manifest-driven nine-set packer |
| verif/sim_main.cpp | Runtime game ID/ROM/input/capture selection and profile-aware assertions |
| verif MAME Lua scripts | Parameterize set, orientation, inputs, checkpoints, and audio/event logging |
| scripts/romsets.json | New canonical manifest generated/checked against MAME |
| releases/*.mra | Nine MRAs, all selecting Universal_DoCastle |
| README.md and docs | Supported-game table, controls, build/test procedure, attributions, known limitations |
| .gitignore | Ignore all local ROM ZIPs and generated captures without hiding source manifests |

The current root is not itself a Git working tree, although the imported reference directory is. Before substantial implementation, establish or confirm the intended source-control root so changes and third-party attribution are traceable.

## 8. Implementation phases and gates

### Phase 0 — Freeze evidence and create reproducible manifests

Tasks:

- Record hashes of current source, captures, simulation output, and Quartus reports.
- Preserve the current docastle reference ROM image and known screenshots.
- Create the nine-set manifest with MAME CRC32/SHA-1 values.
- Generate and hash the fixed ABI image for every set.
- Generate draft MRAs and validate their XML, RBF name, ROM order, fills, buttons, DIP defaults, and rotation.
- Add a source/attribution inventory with pinned external revisions.

Exit gate:

- All nine archives validate without filename, length, CRC32, SHA-1, offset, fill, or total-size errors.
- Re-running generation produces byte-identical streams and MRAs.
- No ROM content enters source control or release packages.

### Phase 1 — Universal foundation and Castle profile

Tasks:

- Add the game-ID loader, descriptor, unknown-ID reset, and fixed ROM ABI.
- Create the Universal_DoCastle Quartus revision and top wrapper without running Quartus.
- Refactor ROM addressing and parameterize the existing map/video behavior.
- Bring up docastle first, preserving the current baseline.
- Bring up douni with ID 01 and verify its distinct program/object/PROM content.
- Add unit tests for descriptor decode, sparse ROM access, TMS1025 pipeline, WAIT handshake, and Castle priority.

Exit gate:

- docastle and douni boot, enter attract, accept coin/start, and reach gameplay.
- No Castle visual, audio, input, timing, or handshake regression versus the frozen baseline.
- MAME and RTL checkpoints align for title, attract, coin/start, flip, and representative sprite-priority scenes.

### Phase 2 — Run Run profile and five games

Tasks:

- Implement Run Run main/sub maps, no VRAM/color mirror, b800 sub NMI, and relocated PSG/communication ports.
- Switch foreground priority to tile pens 0–7.
- Bring up dorunrun as the profile anchor.
- Add dowild, jjack, kickridr, and spiero through data-only descriptors/MRAs unless a verified quirk is required.
- Verify jjack's vertical orientation separately from the four horizontal Run Run games.
- Add long deterministic attract testing and profile-switch/reset testing.

Exit gate:

- All five sets boot, attract, accept input, play, flip, and produce correct four-PSG audio.
- No per-game RTL forks exist for differences representable in descriptors or MRAs.
- Do! Run Run remains synchronized through a long attract run. The real-board-verified dorunrun2 sequence may be used as an optional diagnostic, but it must not be incorrectly imposed on the supplied parent dorunrun set.

### Phase 3 — Soccer profile and two games

Tasks:

- Implement Soccer main map and Castle sub map combination.
- Add 10-bit object codes, four-bit palettes, and Soccer attribute decoding.
- Wire JOYS2 and dual-stick controls.
- Integrate JT5205 and the exact sample controller.
- Bring up idsoccer first, then asoccer.
- Implement game-specific Soccer DIP switches and American Soccer control mode.

Exit gate:

- Both games boot, attract, accept coin/start, and play with usable dual-stick controls.
- Object graphics use the full 0x20000 region without aliasing.
- ADPCM status, bank holes, edge priority, nibble order, playback length, and audible output match MAME.
- Four PSGs and ADPCM mix without wraparound or unexplained clipping.

### Phase 4 — CRTC, handshake, and custom-chip fidelity

Tasks:

- Complete the board-relevant HD6845 behavior and validate MA6-derived sub IRQ timing.
- Compare cursor-derived and VSYNC-derived main/sprite interrupts using controlled builds of the simulator only.
- Audit remaining main/sub cycle differences against current MAME handshake behavior.
- Create a license decision record for the CF37201 material.
- If legally and technically clear, implement a synchronous third-Z80/CF37201/full-framebuffer path.
- Compare its address, frame parity, collision/priority, masking, flip, and double-buffer behavior with decap evidence and the proven direct renderer.

Exit gate:

- No game regresses under the corrected CRTC.
- Interrupt selection is supported by measured evidence, not assumption.
- The custom-chip path becomes production default only if every game passes and it resolves known inaccuracies. Otherwise the MAME-equivalent path remains the release implementation and the limitation is documented.

### Phase 5 — Full automated regression and MAME differential audit

Tasks:

- Run all nine sets serially through one reusable Verilated model.
- Produce scripted title, attract, coin, start, gameplay, flip, service/test, and DIP captures.
- Compare CPU/bus events, frame composition, and audio events to MAME.
- Run thousands of frames per set without deadlock, renderer overrun, or unbounded drift.
- Test successive ROM/profile reloads in multiple orders.

Exit gate:

- Every cell in the acceptance matrix is supported by a reproducible log or artifact.
- All known deviations have a hardware-supported explanation and explicit disposition.
- No test relies only on a screenshot when an event trace can identify the cause.

### Phase 6 — Quartus build and release packaging

Quartus remains stopped until Phase 5 passes. When authorized to build:

- Use the account-wide NUM_PARALLEL_PROCESSORS value of 6 and never override it upward.
- Ensure the active QSF contains FITTER_EFFORT “FAST FIT”, ROUTER_TIMING_OPTIMIZATION_LEVEL NORMAL, both specified physical-synthesis options OFF, SMART_RECOMPILE ON, and SAVE_DISK_SPACE OFF.
- Preserve db and incremental_db for Smart Recompile.
- Keep bitstream compression off.
- Perform one justified build, inspect timing, and rebuild only for a source or timing-closure reason.
- Require non-negative setup, hold, recovery, removal, and minimum-pulse slack in every relevant clock domain.
- Inspect resource usage and confirm ROM/RAM inference.

The current known DoCastle build has approximately -0.227 ns HDMI setup slack and is not release-eligible. The universal RBF must not inherit that waiver.

Release contents:

- Universal_DoCastle.rbf with the exact requested filename.
- Nine separately named MRAs selecting Universal_DoCastle.
- README, controls/DIP documentation, source/third-party notices, supported-set hashes, and a test summary.
- No ROMs.

### Phase 7 — Deferred MiSTer hardware audit

This starts only after explicit user authorization.

Tasks:

- Copy the exact RBF and nine MRAs to MiSTer.
- Boot every supplied set after a cold reset and after switching from another profile.
- Audit digital and analog controllers, both Soccer sticks, coin/service/start, flip, DIP switches, and orientation.
- Capture matched screenshots for title, attract, gameplay, sprite priority, and palette scenes.
- Record direct audio for PSG melody/noise and Soccer ADPCM.
- Compare hardware captures with the approved Verilator and MAME references.
- Fix, rebuild, and repeat until no release-blocking difference remains.

Exit gate:

- All nine sets pass the same acceptance matrix on physical MiSTer.
- Screenshots, audio, controls, timing, and profile switching show no unresolved release-blocking fault.

## 9. Verification strategy

All Verilator model generation/builds must use verilator-safe, after verilator-safe status confirms the machine-wide lock is available. All runs must use verilator-sim-safe or verilator-safe sim. Generated models use one simulation thread, no more than four Verilation jobs, and no more than four C++ build jobs. Runs are serial unless one explicit two-way comparison genuinely requires the comparison mode.

### 9.1 Unit and module tests

- All nine game IDs and the invalid-ID case.
- Three main maps and two sub maps, including mirrors and sparse ROM holes.
- Main/sub latch direction, WAIT assertion/release, retries, and back-to-back LDIR transfers.
- TMS1025 previous-selection read pipeline, select zero, flip writes, and JOYS2.
- Standard versus Soccer sprite attribute decode.
- Castle versus low-pen tile priority.
- Pen-15 sprite masking and reverse list order.
- Palette PROM conversion.
- Four PSG READY aggregation.
- ADPCM falling edges, start-over-stop priority, bank selection, empty bank, nibble order, and terminal status.
- CRTC register effects, raster counts, VSYNC, cursor, DE, MA, and MA6 transition.

### 9.2 Per-run assertions

- CPU PCs and buses continue advancing.
- Main WAIT cannot remain asserted without a pending transfer.
- Exact active raster count is 240 × 192 = 46,080 pixels per frame.
- Frame cadence remains within the exact rational-clock expectation.
- No unknown game/profile bits.
- No ROM access beyond its fixed region.
- No line-renderer deadline overrun.
- At least one nonblank title/attract frame.
- Audio register activity where expected.
- Soccer sample playback starts, advances, and terminates.

### 9.3 MAME comparison artifacts

The Lua capture tooling will be parameterized by set and scripted event, producing:

- Frame PNG and raw palette-index/scanline CRC data.
- Main/sub/sprite CPU PC and critical bus-event logs.
- Video RAM, color RAM, sprite RAM, input mux, flip, interrupt, and WAIT events.
- PSG writes with device index and timestamp.
- ADPCM control, bank, address, nibble, status, and VCLK events.
- An input/event timeline so comparisons align on state transitions rather than arbitrary frame numbers.

Frame comparisons must be orientation-aware and report exact pixels, mean/max channel error, bounding boxes, and scanline hashes. Audio comparison should first prove register/nibble event equivalence, then compare resampled waveform, envelope, spectrum, silence, clipping, and channel balance.

### 9.4 Acceptance matrix

Each row must finish with evidence for every column:

| Game | Boot/title | Attract/long run | Coin/start/gameplay | Controls/service | DIP/flip/orientation | Tiles/sprites/priority | PSG | ADPCM | MAME differential | MiSTer |
|---|---|---|---|---|---|---|---|---|---|---|
| docastle | Pass | Pass, 481f | Pass, scripted | RTL/lint; hardware deferred | MRA pass; hardware deferred | Pass | Pass/activity | N/A | Title/attract 100%; gameplay 99.290% | Deferred |
| douni | Pass | Pass, 481f | Pass, scripted | RTL/lint; hardware deferred | MRA pass; hardware deferred | Pass | Pass/activity | N/A | Title/attract 100%; gameplay 99.290% | Deferred |
| dorunrun | Pass | Pass, 481f | Pass, scripted | RTL/lint; hardware deferred | MRA pass; hardware deferred | Pass | Pass/activity | N/A | Title/attract 100%; gameplay 99.501% | Deferred |
| dowild | Pass | Pass, 481f | Pass, scripted | RTL/lint; hardware deferred | MRA pass; hardware deferred | Pass | Pass/activity | N/A | Title/attract 100%; gameplay 99.731% | Deferred |
| jjack | Pass | Pass, 481f | Pass, scripted | RTL/lint; hardware deferred | MRA pass; hardware deferred | Pass | Pass/activity | N/A | Title/attract 100%; gameplay 98.947% | Deferred |
| kickridr | Pass | Pass, 481f | Pass, scripted | RTL/lint; hardware deferred | MRA pass; hardware deferred | Pass | Pass/activity | N/A | Title/attract 100%; gameplay 99.423% | Deferred |
| spiero | Pass | Pass, 481f | Pass, scripted | RTL/lint; hardware deferred | MRA pass; hardware deferred | Pass | Pass/activity | N/A | Title 100%; attract 99.601%; gameplay 99.479% | Deferred |
| idsoccer | Pass | Pass, 481f | Pass, scripted | RTL/lint; hardware deferred | MRA pass; hardware deferred | Pass | Pass/activity | Pass; 3,008 strobes, peak -13.25 dBFS | Title/attract 100%; gameplay 98.416% | Deferred |
| asoccer | Pass | Pass, 481f | Pass, scripted | RTL/lint; hardware deferred | MRA pass; hardware deferred | Pass | Pass/activity | Pass; 2,874 strobes, peak -13.25 dBFS | Title/attract 100%; gameplay 97.951% | Deferred |

“Pass” requires a linked log/capture and not merely a visual assertion.

## 10. Principal risks and required decisions

| Risk | Mitigation / decision gate |
|---|---|
| Main/sub handshake is cycle-sensitive | Event-level trace comparison, targeted minimal tests, no timeout hacks |
| TMS1025 has no identified TI public documentation | Preserve MAME's pipelined model, validate all selectors, use real-game timing |
| Cursor versus VSYNC discrepancy | Match current MAME first; change only after schematic/PCB evidence and nine-game regression |
| MAME bypasses third Z80 and CF37201 | Functional direct renderer first; decap-informed custom path as a separately gated milestone |
| CF37201 reproduction license/uncertain equations | Do not import until permission/compatibility is clear; otherwise independent implementation |
| Soccer dual-stick UX differs by controller | Analog mapping plus documented digital fallback; test multiple controller types later |
| Soccer sample ROM has an empty socket | Explicit zero fill at 0x4000–0x7fff and unit tests |
| Run Run deterministic attract sequence varies by revision | Do not use dorunrun2's board sequence as an exact oracle for parent dorunrun |
| Watchdog timeout is not established | Decode/observe strobe first; implement reset only from verified board evidence |
| Universal build may lose timing | Software gates first, one Fast Fit build, inspect all timing before deployment |
| Root project lacks Git metadata | Confirm/create the intended source-control root before large changes |

## 11. Definition of done

The core is complete for this plan when:

1. Universal_DoCastle.rbf is the only FPGA binary required by all nine MRAs.
2. Each MRA validates its exact ROM set, loads the fixed ABI and stable ID, exposes correct controls/DIPs, and applies correct native rotation.
3. All nine games cold-boot, run attract mode, accept coin/start, enter gameplay, flip correctly, and survive long runs without CPU deadlock or renderer overrun.
4. Castle, Run Run, and Soccer maps, priorities, sprite formats, input mux behavior, interrupts, and clocks match the approved evidence.
5. Four-PSG sound works for every title and Soccer ADPCM matches bank, edge, nibble, status, timing, and mix behavior.
6. Automated Verilator regressions and MAME differential artifacts pass for every row of the matrix.
7. Quartus timing is clean in all reported domains and the generated RBF is built from the audited source/revision.
8. Once hardware testing is authorized, all nine pass a MiSTer screenshot, audio, controls, orientation, reset, and profile-switch audit.
9. Licensing and attribution are complete, and no ROM data is distributed.
10. Remaining deviations, if any, are non-release-blocking, evidence-backed, and explicitly documented rather than hidden.

## 12. Online and hardware references

Primary and high-value references:

- MAME driver: https://github.com/mamedev/mame/blob/master/src/mame/universal/docastle.cpp
- MAME TMS1025 input implementation history: https://github.com/mamedev/mame/commit/d31f08ef
- MAME main/sub and SN READY correction: https://github.com/mamedev/mame/commit/2d94f582
- MAME cycle-handshake correction: https://github.com/mamedev/mame/commit/2b37fd59
- MAME Soccer ADPCM correction: https://github.com/mamedev/mame/commit/97ca2ae8
- MAME palette blue-channel correction: https://github.com/mamedev/mame/commit/d78d98db
- MAME Testers Do! Run Run timing report: https://mametesters.org/view.php?id=1021
- Furrtek CF37201N folder: https://github.com/furrtek/SiliconRE/tree/master/Misc/CF37201N
- Furrtek reproduction Verilog: https://github.com/furrtek/SiliconRE/blob/master/Misc/CF37201N/Repro/CF37201N.v
- Furrtek decap schematic: https://github.com/furrtek/SiliconRE/blob/master/Misc/CF37201N/CF37201N_schematics.pdf
- Furrtek pinout: https://github.com/furrtek/SiliconRE/blob/master/Misc/CF37201N/CF37201N_pinout.ods
- Furrtek gate trace: https://github.com/furrtek/SiliconRE/blob/master/Misc/CF37201N/CF37201N_trace.svg
- JT5205: https://github.com/jotego/jt5205
- JT89: https://github.com/jotego/jt89
- MiSTer MRA format: https://mister-devel.github.io/MkDocs_MiSTer/developer/mra/
- MiSTer Mr. Do reference core, earlier hardware: https://github.com/MiSTer-devel/Arcade-MrDo_MiSTer
- FinalBurn Neo secondary driver: https://github.com/finalburnneo/FBNeo/blob/master/src/burn/drv/pre90s/d_docastle.cpp

Manuals and PCB evidence:

- Mr. Do's Castle service manual/schematics: https://arcarc.xmission.com/PDF_Arcade_Manuals_and_Schematics/Mr%20Do%20Castle.pdf
- Mr. Do! vs. Unicorns manual: https://www.gamesdatabase.org/Media/SYSTEM/Arcade/Manual/formated/Mr._Do_vs._Unicorns_-_1983_-_Universal.pdf
- Mr. Do's Wild Ride service manual: https://arcarc.xmission.com/PDF_Arcade_Manuals_and_Schematics/Mr%20Do%27s%20Wild%20Ride.pdf
- Do! Run Run manual: https://arcarc.xmission.com/PDF_Arcade_Manuals_and_Schematics/Mr%20Do%20Run%20Run%20%28no%20schematics%29.pdf
- Indoor Soccer manual: https://manuals.plus/m/0d40a8b03c717afeac2580216f5cdc923c6cae983bbd03705f215caa640201a3
- Mr. Do's Wild Ride PCB information: https://www.arcade-museum.com/Videogame/mr-do-s-wild-ride
- Kick Rider PCB information: https://www.arcade-museum.com/Videogame/kick-rider
- Universal PCB cross-reference: https://forums.arcade-museum.com/threads/universal-board-s.85312/
- American Soccer original-board report: https://forums.arcade-museum.com/threads/rare-prototype-american-soccer-pcb.86126/

This document records the implementation order and release gates. It does not authorize skipping a failed gate merely because a game appears to boot.
