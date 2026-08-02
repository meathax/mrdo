param(
    [string]$VerilatorSafe = $(if ($env:VERILATOR_SAFE) { $env:VERILATOR_SAFE } else { "C:\Users\meath\bin\verilator-safe.exe" })
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot

& $VerilatorSafe status
if ($LASTEXITCODE -ne 0) { throw "verilator-safe status failed before visual build" }

$buildTemp = Join-Path $projectRoot "build_tmp"
New-Item -ItemType Directory -Force -Path $buildTemp | Out-Null

$sdlCflags = (& "C:\msys64\ucrt64\bin\pkg-config.exe" --cflags sdl2).Trim()
$sdlLibs = (& "C:\msys64\ucrt64\bin\pkg-config.exe" --libs sdl2).Trim()
$sdlCflags = $sdlCflags.Replace("-Dmain=SDL_main", "")
$sdlLibs = $sdlLibs.Replace("-lSDL2main", "").Replace("-mwindows", "")
$cflags = "-D_GLIBCXX_USE_CXX11_ABI=0 -DSDL_MAIN_HANDLED -O3 -march=native -mtune=native -fomit-frame-pointer $sdlCflags"
$sources = @(
    "rtl/docastle_profile.sv", "rtl/docastle_rom.sv", "rtl/docastle_main.sv",
    "rtl/docastle_sub.sv", "rtl/docastle_spritecpu.sv", "rtl/docastle_cf37201.sv",
    "rtl/docastle_crtc.sv", "rtl/docastle_pcb_sprite.sv", "rtl/docastle_video.sv",
    "rtl/docastle_adpcm.sv", "rtl/docastle_audio_filter.sv", "rtl/docastle_core.sv",
    "rtl/jt89/jt12_comb.v", "rtl/jt89/jt12_dac2.v", "rtl/jt89/jt12_interpol.v",
    "rtl/jt89/jt89.v", "rtl/jt89/jt89_mixer.v", "rtl/jt89/jt89_noise.v",
    "rtl/jt89/jt89_sms.v", "rtl/jt89/jt89_tone.v", "rtl/jt89/jt89_vol.v",
    "rtl/jt5205/jt5205.v", "rtl/jt5205/jt5205_timing.v",
    "rtl/jt5205/jt5205_adpcm.v", "rtl/jt5205/jt5205_interpol2x.v",
    "verif/tv80/T80se.v", "verif/tv80/tv80_alu.v", "verif/tv80/tv80_core.v",
    "verif/tv80/tv80_mcode.v", "verif/tv80/tv80_reg.v", "verif/tv80/tv80s.v",
    "verif/sim_visual.cpp"
)
$sourceText = $sources -join " "
$bashRoot = $projectRoot.Replace("\", "/").Replace(":", "")
$bashCommand = "export MSYSTEM=UCRT64; export PATH=/ucrt64/bin:/usr/bin:`$PATH; export TMPDIR=/d/$($bashRoot.Substring(1)); export TMPDIR=/d/$($bashRoot.Substring(1))/build_tmp; export TMP=`$TMPDIR; export TEMP=`$TMPDIR; cd /d/$($bashRoot.Substring(1)); /c/Users/meath/bin/verilator-safe.exe --cc --exe --build --no-timing -O3 -Wno-fatal -DSIMULATION --top-module docastle_core --Mdir obj_dir_visual --threads 1 --verilate-jobs 4 --build-jobs 4 -CFLAGS `"$cflags`" -LDFLAGS `"$sdlLibs`" $sourceText"
& "C:\msys64\usr\bin\bash.exe" -lc $bashCommand
if ($LASTEXITCODE -ne 0) { throw "safe visual Verilator build failed" }
$executable = Join-Path $projectRoot "obj_dir_visual\Vdocastle_core.exe"
if (-not (Test-Path -LiteralPath $executable)) { throw "visual executable was not produced: $executable" }
Write-Host "PASS visual build Verilator=5.050 top=docastle_core executable=$executable"
