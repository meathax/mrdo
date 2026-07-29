param(
	[string]$Manifest,
	[string]$MameDirectory,
	[string]$CoreDirectory,
	[string]$OutputJson,
	[double]$SkipStartSeconds = 1.0
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
if (-not $Manifest) { $Manifest = Join-Path $projectRoot "scripts\romsets.json" }
if (-not $MameDirectory) { $MameDirectory = Join-Path $PSScriptRoot "mame" }
if (-not $CoreDirectory) { $CoreDirectory = Join-Path $PSScriptRoot "out" }
if (-not $OutputJson) { $OutputJson = Join-Path $CoreDirectory "audio-comparison.json" }

$definition = Get-Content -LiteralPath $Manifest -Raw | ConvertFrom-Json
$results = @()
foreach ($game in $definition.sets) {
	$mamePath = Join-Path $MameDirectory "$($game.set)_gameplay.wav"
	$corePath = Join-Path $CoreDirectory "$($game.set)_gameplay.wav"
	$mame = & (Join-Path $PSScriptRoot "analyze_wav.ps1") -Path $mamePath -SkipStartSeconds $SkipStartSeconds
	$core = & (Join-Path $PSScriptRoot "analyze_wav.ps1") -Path $corePath -SkipStartSeconds $SkipStartSeconds
	$results += [PSCustomObject]@{
		Set = $game.set
		Profile = $game.profile
		CoreSeconds = $core.DurationSeconds
		MameSeconds = $mame.DurationSeconds
		CorePeakDbFS = $core.PeakDbFS
		MamePeakDbFS = $mame.PeakDbFS
		CoreRmsDbFS = $core.RmsDbFS
		MameRmsDbFS = $mame.RmsDbFS
		RmsDeltaDb = [math]::Round($core.RmsDbFS-$mame.RmsDbFS,3)
		CoreZeroPercent = $core.ZeroPercent
		MameZeroPercent = $mame.ZeroPercent
		CoreClipped = $core.ClippedSamples
		MameClipped = $mame.ClippedSamples
	}
}

$results | ConvertTo-Json | Set-Content -LiteralPath $OutputJson -Encoding UTF8
$results | Format-Table Set,Profile,CorePeakDbFS,MamePeakDbFS,CoreRmsDbFS,MameRmsDbFS,RmsDeltaDb,CoreClipped
Write-Host "Wrote $OutputJson"
