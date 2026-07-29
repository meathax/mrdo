param(
	[string]$SetName = "all",
	[string]$MameExe = $(if ($env:MAME_EXE) { $env:MAME_EXE } else { "mame" }),
	[string]$OutputDirectory = (Join-Path $PSScriptRoot "mame"),
	[string]$Manifest = (Join-Path (Split-Path -Parent $PSScriptRoot) "scripts\romsets.json")
)

$ErrorActionPreference = "Stop"
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
if (-not (Get-Command -Name $MameExe -ErrorAction SilentlyContinue) -and -not (Test-Path -LiteralPath $MameExe)) {
	throw "MAME executable not found: $MameExe"
}

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$env:DOCASTLE_CAPTURE_DIR = [IO.Path]::GetFullPath($OutputDirectory)
try {
	foreach ($game in $requested) {
		Write-Host "Capturing MAME set $($game.set)"
		$wavPath = Join-Path $OutputDirectory "$($game.set)_gameplay.wav"
		$mameArguments = @(
			$game.set,
			"-rompath", $projectRoot,
			"-skip_gameinfo",
			"-nothrottle",
			"-video", "none",
			"-sound", "none",
			"-samplerate", "48000",
			"-wavwrite", $wavPath,
			"-autoboot_script", (Join-Path $PSScriptRoot "mame_capture.lua")
		)
		& $MameExe @mameArguments
		if ($LASTEXITCODE -ne 0) {
			throw "MAME exited with code $LASTEXITCODE for $($game.set)"
		}
		foreach ($label in "title","attract","gameplay") {
			$capture = Join-Path $OutputDirectory "$($game.set)_$label.png"
			if (-not (Test-Path -LiteralPath $capture)) {
				throw "MAME did not create $capture"
			}
		}
		if (-not (Test-Path -LiteralPath $wavPath)) {
			throw "MAME did not create $wavPath"
		}
	}
} finally {
	Remove-Item Env:DOCASTLE_CAPTURE_DIR -ErrorAction SilentlyContinue
}
