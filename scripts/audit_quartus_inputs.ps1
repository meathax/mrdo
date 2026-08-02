param(
	[string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"
$qpf = Join-Path $ProjectRoot "Universal_DoCastle.qpf"
$qsf = Join-Path $ProjectRoot "Universal_DoCastle.qsf"
$sdc = Join-Path $ProjectRoot "Universal_DoCastle.sdc"
$fileList = Join-Path $ProjectRoot "files.qip"

foreach ($requiredFile in $qpf,$qsf,$sdc,$fileList,(Join-Path $ProjectRoot "Universal_DoCastle.sv")) {
	if (-not (Test-Path -LiteralPath $requiredFile)) {
		throw "Missing Quartus input: $requiredFile"
	}
}

$qpfText = Get-Content -LiteralPath $qpf -Raw
if ($qpfText -notmatch 'PROJECT_REVISION\s*=\s*"Universal_DoCastle"') {
	throw "Universal_DoCastle.qpf has the wrong revision"
}

$qsfText = Get-Content -LiteralPath $qsf -Raw
$requiredAssignments = @(
	'TOP_LEVEL_ENTITY sys_top',
	'NUM_PARALLEL_PROCESSORS 6',
	'SAVE_DISK_SPACE OFF',
	'SMART_RECOMPILE ON',
	'PHYSICAL_SYNTHESIS_COMBO_LOGIC OFF',
	'PHYSICAL_SYNTHESIS_REGISTER_DUPLICATION OFF',
	'ROUTER_TIMING_OPTIMIZATION_LEVEL NORMAL',
	'FITTER_EFFORT "FAST FIT"',
	'SDC_FILE Universal_DoCastle.sdc',
	'SYSTEMVERILOG_FILE Universal_DoCastle.sv'
)
foreach ($assignment in $requiredAssignments) {
	if (-not $qsfText.Contains($assignment)) {
		throw "Universal_DoCastle.qsf is missing: $assignment"
	}
}

$listedSources = @()
foreach ($line in (Get-Content -LiteralPath $fileList)) {
	if ($line -match 'FILE\s+(.+)$') {
		$relative = $Matches[1].Trim()
		$listedSources += $relative
		if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot $relative))) {
			throw "files.qip references missing path: $relative"
		}
	}
}

$sdcText = Get-Content -LiteralPath $sdc -Raw
foreach ($constraint in "derive_pll_clocks","derive_clock_uncertainty","set_false_path") {
	if (-not $sdcText.Contains($constraint)) {
		throw "Universal_DoCastle.sdc is missing $constraint"
	}
}

$releaseRbf = Join-Path $ProjectRoot "releases\DoCastle.rbf"
$outputRbf = Join-Path $ProjectRoot "output_files\Universal_DoCastle.rbf"
$rbfGenerated = Test-Path -LiteralPath $releaseRbf
$status = "INPUTS_READY"
if ($rbfGenerated) {
	if (-not (Test-Path -LiteralPath $outputRbf)) {
		throw "Release RBF exists but the Quartus output RBF is missing"
	}
	$releaseItem = Get-Item -LiteralPath $releaseRbf
	if ($releaseItem.Length -le 0) {
		throw "Release RBF is empty"
	}
	$releaseHash = (Get-FileHash -LiteralPath $releaseRbf -Algorithm SHA256).Hash
	$outputHash = (Get-FileHash -LiteralPath $outputRbf -Algorithm SHA256).Hash
	if ($releaseHash -ne $outputHash) {
		throw "Release RBF does not match the Quartus output RBF"
	}
	$status = "BUILD_COMPLETE_RELEASE_MATCHES_OUTPUT"
}

[PSCustomObject]@{
	Revision = "Universal_DoCastle"
	QsfPolicyAssignments = $requiredAssignments.Count
	ListedSourceEntries = $listedSources.Count
	RbfGenerated = $rbfGenerated
	Status = $status
}
