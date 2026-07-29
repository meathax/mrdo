param(
	[string]$WslDistribution = "Ubuntu",
	[string]$VerilatorSafe = $(if ($env:VERILATOR_SAFE) { $env:VERILATOR_SAFE } else { "/home/meath/.local/bin/verilator-safe" })
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$drive = $projectRoot.Substring(0,1).ToLowerInvariant()
$rest = $projectRoot.Substring(2).Replace("\","/")
$wslProjectRoot = "/mnt/$drive$rest"

& wsl.exe -d $WslDistribution --exec $VerilatorSafe status
if ($LASTEXITCODE -ne 0) {
	throw "verilator-safe status failed before wrapper lint"
}

$sources = @(
	"verif/mister_wrapper_stubs.sv",
	"rtl/crt_adjust.sv",
	"sys/math.sv",
	"sys/video_freak.sv",
	"Universal_DoCastle.sv",
	"rtl/pause.v",
	"rtl/docastle_profile.sv",
	"rtl/docastle_analog.sv",
	"rtl/docastle_rom.sv",
	"rtl/docastle_main.sv",
	"rtl/docastle_sub.sv",
	"rtl/docastle_spritecpu.sv",
	"rtl/docastle_cf37201.sv",
	"rtl/docastle_crtc.sv",
	"rtl/docastle_pcb_sprite.sv",
	"rtl/docastle_video.sv",
	"rtl/docastle_adpcm.sv",
	"rtl/docastle_audio_filter.sv",
	"rtl/docastle_core.sv",
	"rtl/jt89/jt12_comb.v",
	"rtl/jt89/jt12_dac2.v",
	"rtl/jt89/jt12_interpol.v",
	"rtl/jt89/jt89.v",
	"rtl/jt89/jt89_mixer.v",
	"rtl/jt89/jt89_noise.v",
	"rtl/jt89/jt89_sms.v",
	"rtl/jt89/jt89_tone.v",
	"rtl/jt89/jt89_vol.v",
	"rtl/jt5205/jt5205.v",
	"rtl/jt5205/jt5205_timing.v",
	"rtl/jt5205/jt5205_adpcm.v",
	"rtl/jt5205/jt5205_interpol2x.v",
	"verif/tv80/T80se.v",
	"verif/tv80/tv80_alu.v",
	"verif/tv80/tv80_core.v",
	"verif/tv80/tv80_mcode.v",
	"verif/tv80/tv80_reg.v",
	"verif/tv80/tv80s.v"
)

$arguments = @(
	"-d", $WslDistribution,
	"--cd", $wslProjectRoot,
	"--exec", $VerilatorSafe,
	"--lint-only", "--no-timing", "-Wno-fatal", "-Wno-TIMESCALEMOD",
	"-DMISTER_FB", "-DSIMULATION", "--top-module", "emu",
	"--threads", "1", "--verilate-jobs", "4"
) + $sources

& wsl.exe @arguments
if ($LASTEXITCODE -ne 0) {
	throw "Universal_DoCastle wrapper lint failed"
}
Write-Host "PASS Universal_DoCastle wrapper and full RTL lint"
