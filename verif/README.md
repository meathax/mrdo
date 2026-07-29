# Universal_DoCastle verification

## ROM and MRA preparation

From the project root:

    powershell -ExecutionPolicy Bypass -File verif/prepare_rom.ps1 -SetName all
    powershell -ExecutionPolicy Bypass -File scripts/generate_mras.ps1
    powershell -ExecutionPolicy Bypass -File scripts/validate_mras.ps1

The packer validates each ZIP container, ROM filename, length, CRC32, and SHA-1
against scripts/romsets.json. It writes nine 0x48400-byte images under
verif/out and records their MD5/SHA-1 values.

## Safe Verilator build

Never delete obj_dir_wsl. Check the machine-wide lock first and build the model
once under WSL:

    verilator-safe status
    verilator-safe --cc --exe --build --no-timing -O3 -Wno-fatal \
      -DSIMULATION --top-module docastle_core --Mdir obj_dir_wsl \
      --threads 1 --verilate-jobs 4 --build-jobs 4 \
      rtl/docastle_profile.sv rtl/docastle_rom.sv rtl/docastle_main.sv \
      rtl/docastle_sub.sv rtl/docastle_spritecpu.sv rtl/docastle_video.sv \
      rtl/docastle_adpcm.sv rtl/docastle_core.sv rtl/jt89/*.v \
      rtl/jt5205/*.v verif/tv80/*.v verif/sim_main.cpp

The generated model is single-threaded. Runtime changes to ROM, game ID,
frame count, input events, or capture paths do not require rebuilding.

Lint the complete `emu` wrapper against exact-width MiSTer framework stubs
without invoking Quartus:

    powershell -ExecutionPolicy Bypass -File verif/lint_wrapper.ps1

## Safe regression

verif/run_regression.ps1 checks safe-launcher status and runs requested sets
serially through verilator-sim-safe:

    powershell -ExecutionPolicy Bypass -File verif/run_regression.ps1 \
      -SetName all -Frames 5

Add -Play for the scripted coin/start sequence and WAV output. The harness
checks the game/profile ID, 46,080 visible pixels per frame, all three CPU
buses, main WAIT duration, renderer deadline, nonblack video, and ADPCM event
count. It never enables tracing by default.

## MAME references

The current local reference executable and the supplied ZIPs can produce
title, attract, and gameplay captures for all sets:

    powershell -ExecutionPolicy Bypass -File verif/run_mame_capture.ps1 \
      -SetName all

Use compare_frames.ps1 with the set name; it automatically applies ROT270 only
for docastle, douni, and jjack.

Tracing is added only after reproducing a specific failure without it, using a
short FST window and shallow trace depth.
