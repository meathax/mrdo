param(
	[string]$Checkpoint = "title",
	[string]$CoreSuffix = "frame122",
	[switch]$RequireExact,
	[string]$Manifest,
	[string]$MameDirectory,
	[string]$CoreDirectory,
	[string]$OutputJson
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $Manifest) { $Manifest = Join-Path $projectRoot "scripts\romsets.json" }
if (-not $MameDirectory) { $MameDirectory = Join-Path $PSScriptRoot "mame" }
if (-not $CoreDirectory) { $CoreDirectory = Join-Path $PSScriptRoot "out" }
if (-not $OutputJson) { $OutputJson = Join-Path $CoreDirectory "$Checkpoint-comparison.json" }

$definition = Get-Content -LiteralPath $Manifest -Raw | ConvertFrom-Json
$results = @()
foreach ($game in $definition.sets) {
	$mameImage = Join-Path $MameDirectory "$($game.set)_$Checkpoint.png"
	$coreImage = Join-Path $CoreDirectory "$($game.set)_$CoreSuffix.bmp"
	$oriented = Join-Path $CoreDirectory "$($game.set)_${CoreSuffix}_oriented.png"
	foreach ($path in $mameImage,$coreImage) {
		if (-not (Test-Path -LiteralPath $path)) { throw "Missing comparison input: $path" }
	}
	$result = & (Join-Path $PSScriptRoot "compare_frames.ps1") `
		-MameImage $mameImage -CoreImage $coreImage -SetName $game.set `
		-Manifest $Manifest -OrientedOutput $oriented
	$results += $result
	if ($RequireExact -and ($result.ExactPercent -ne 100)) {
		throw "$($game.set) $Checkpoint comparison is $($result.ExactPercent)% instead of exact"
	}
}

$results | ConvertTo-Json | Set-Content -LiteralPath $OutputJson -Encoding UTF8
$results | Format-Table Set,Width,Height,ExactPercent,MeanAbsoluteErrorPerChannel,MaxChannelError
Write-Host "Wrote $OutputJson"
