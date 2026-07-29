param(
	[string]$SetName = "all",
	[int]$Frames = 5,
	[switch]$Play,
	[string]$Manifest = (Join-Path (Split-Path -Parent $PSScriptRoot) "scripts\romsets.json"),
	[string]$WslDistribution = "Ubuntu",
	[string]$VerilatorSafe = $(if ($env:VERILATOR_SAFE) { $env:VERILATOR_SAFE } else { "verilator-safe" }),
	[string]$VerilatorSimSafe = $(if ($env:VERILATOR_SIM_SAFE) { $env:VERILATOR_SIM_SAFE } else { "verilator-sim-safe" })
)

$ErrorActionPreference = "Stop"
if ($Frames -lt 1) {
	throw "Frames must be positive"
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$definition = Get-Content -LiteralPath $Manifest -Raw | ConvertFrom-Json
$requested = if ($SetName -eq "all") {
	@($definition.sets)
} else {
	@($definition.sets | Where-Object { $_.set -eq $SetName })
}
if ($requested.Count -eq 0) {
	throw "Unknown set '$SetName'"
}

$drive = $projectRoot.Substring(0,1).ToLowerInvariant()
$rest = $projectRoot.Substring(2).Replace("\","/")
$wslProjectRoot = "/mnt/$drive$rest"
$model = "obj_dir_wsl/Vdocastle_core"

foreach ($game in $requested) {
	& wsl.exe -d $WslDistribution --exec $VerilatorSafe status
	if ($LASTEXITCODE -ne 0) {
		throw "verilator-safe status failed before $($game.set)"
	}

	$rom = "verif/out/$($game.set).rom"
	$frameStem = if ($Play) { "$($game.set)_gameplay" } else { "$($game.set)_frame$Frames" }
	$frame = "verif/out/$frameStem.ppm"
	$arguments = @(
		"-d", $WslDistribution,
		"--cd", $wslProjectRoot,
		"--exec", $VerilatorSimSafe,
		"--", $model, $rom, [string]$game.id, [string]$Frames, $frame
	)
	if ($Play) {
		$arguments += "play"
		$arguments += "verif/out/$($game.set)_gameplay.wav"
		$arguments += "verif/out/$($game.set)_title.ppm"
		$arguments += "verif/out/$($game.set)_attract.ppm"
	}

	Write-Host "Running $($game.set), ID $($game.id), $Frames frames"
	$runTag = if ($Play) { "play$Frames" } else { "frame$Frames" }
	$logPath = Join-Path $projectRoot "verif/out/$($game.set)_$runTag.log"
	$simOutput = & wsl.exe @arguments 2>&1
	$simExit = $LASTEXITCODE
	$simOutput | ForEach-Object { Write-Host $_ }
	$simOutput | Set-Content -LiteralPath $logPath -Encoding UTF8
	if ($simExit -ne 0) {
		throw "Safe Verilator simulation failed for $($game.set)"
	}

	& (Join-Path $PSScriptRoot "ppm_to_bmp.ps1") `
		-InputPath (Join-Path $projectRoot $frame) `
		-OutputPath (Join-Path $projectRoot "verif/out/$frameStem.bmp") | Out-Null
	if ($Play) {
		foreach ($checkpoint in @("title", "attract")) {
			& (Join-Path $PSScriptRoot "ppm_to_bmp.ps1") `
				-InputPath (Join-Path $projectRoot "verif/out/$($game.set)_$checkpoint.ppm") `
				-OutputPath (Join-Path $projectRoot "verif/out/$($game.set)_$checkpoint.bmp") | Out-Null
		}
	}
}
