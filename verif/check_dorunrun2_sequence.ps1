param(
	[int]$Frames = 18001,
	[string]$WslDistribution = "Ubuntu",
	[string]$VerilatorSafe = $(if ($env:VERILATOR_SAFE) { $env:VERILATOR_SAFE } else { "/home/meath/.local/bin/verilator-safe" }),
	[string]$VerilatorSimSafe = $(if ($env:VERILATOR_SIM_SAFE) { $env:VERILATOR_SIM_SAFE } else { "/home/meath/.local/bin/verilator-sim-safe" })
)
$ErrorActionPreference = "Stop"
if ($Frames -lt 3) { throw "At least three frames are required" }
$projectRoot = Split-Path -Parent $PSScriptRoot
foreach ($archive in @("dorunrun2.zip","dorunrun.zip")) {
	if (-not (Test-Path -LiteralPath (Join-Path $projectRoot $archive))) {
		throw "Missing $archive. The clone and parent archives are both required; no ROM data is bundled with the core."
	}
}
& (Join-Path $PSScriptRoot "prepare_rom.ps1") `
	-SetName dorunrun2 `
	-Manifest (Join-Path $PSScriptRoot "dorunrun2_romset.json")
if ($LASTEXITCODE -ne 0) { throw "dorunrun2 ROM validation/packing failed" }

$drive = $projectRoot.Substring(0,1).ToLowerInvariant()
$rest = $projectRoot.Substring(2).Replace("\","/")
$wslRoot = "/mnt/$drive$rest"
& wsl.exe -d $WslDistribution --exec $VerilatorSafe status
if ($LASTEXITCODE -ne 0) { throw "verilator-safe status failed" }
$args = @(
	"-d",$WslDistribution,"--cd",$wslRoot,"--exec",$VerilatorSimSafe,"--",
	"obj_dir_wsl/Vdocastle_core","verif/out/dorunrun2.rom","9",[string]$Frames,
	"verif/out/dorunrun2_sequence.ppm","none","-","-","-",
	"--pcb","--timing-check","--events=verif/out/dorunrun2_sequence_events.csv"
)
& wsl.exe @args
if ($LASTEXITCODE -ne 0) { throw "Do! Run Run set 2 cadence run failed" }
Write-Host "PASS dorunrun2 exact ROM hashes, all-OFF DIPs, rational cadence, watchdog, and PCB event timing"
Write-Host "Compare the captured run with verif/dorunrun2_sequence_oracle.md; action recognition remains manual until ROM-derived state signatures can be recorded."
