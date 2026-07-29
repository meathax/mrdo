param(
	[int]$Frames = 721,
	[string]$WslDistribution = "Ubuntu",
	[string]$VerilatorSafe = "/home/meath/.local/bin/verilator-safe",
	[string]$VerilatorSimSafe = "/home/meath/.local/bin/verilator-sim-safe"
)
$ErrorActionPreference = "Stop"
if ($Frames -lt 3) { throw "At least three frames are required" }
$projectRoot = Split-Path -Parent $PSScriptRoot
$drive = $projectRoot.Substring(0,1).ToLowerInvariant()
$rest = $projectRoot.Substring(2).Replace("\","/")
$wslRoot = "/mnt/$drive$rest"
& wsl.exe -d $WslDistribution --exec $VerilatorSafe status
if ($LASTEXITCODE -ne 0) { throw "verilator-safe status failed" }
$args = @(
	"-d",$WslDistribution,"--cd",$wslRoot,"--exec",$VerilatorSimSafe,"--",
	"obj_dir_wsl/Vdocastle_core","verif/out/dorunrun.rom","2",[string]$Frames,
	"verif/out/dorunrun_timing.ppm","none","-","-","-",
	"--pcb","--timing-check","--events=verif/out/dorunrun_timing_events.csv"
)
& wsl.exe @args
if ($LASTEXITCODE -ne 0) { throw "Do! Run Run timing check failed" }
Write-Host "PASS Do! Run Run rational cadence, watchdog, and event timing"
