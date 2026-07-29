param(
	[Parameter(Mandatory=$true)][string]$MameImage,
	[Parameter(Mandatory=$true)][string]$CoreImage,
	[string]$SetName = "docastle",
	[string]$Manifest,
	[string]$OrientedOutput
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
if (-not $Manifest) {
	$Manifest = Join-Path (Split-Path -Parent $PSScriptRoot) "scripts\romsets.json"
}

$definition = Get-Content -LiteralPath $Manifest -Raw | ConvertFrom-Json
$game = $definition.sets | Where-Object { $_.set -eq $SetName } | Select-Object -First 1
if (-not $game) {
	throw "Unknown set '$SetName'"
}

$reference = [Drawing.Bitmap]::new((Resolve-Path $MameImage).Path)
$core = [Drawing.Bitmap]::new((Resolve-Path $CoreImage).Path)
try {
	if ($game.rotation -eq "vertical (ccw)") {
		$core.RotateFlip([Drawing.RotateFlipType]::Rotate270FlipNone)
	}
	if (($reference.Width -ne $core.Width) -or ($reference.Height -ne $core.Height)) {
		throw "Dimension mismatch: MAME $($reference.Width)x$($reference.Height), core $($core.Width)x$($core.Height)."
	}

	[long]$absolute = 0
	[long]$exact = 0
	[int]$maxChannel = 0
	$minX = $core.Width
	$minY = $core.Height
	$maxX = -1
	$maxY = -1
	for ($y=0; $y -lt $core.Height; $y++) {
		for ($x=0; $x -lt $core.Width; $x++) {
			$a = $reference.GetPixel($x,$y)
			$b = $core.GetPixel($x,$y)
			$dr = [math]::Abs($a.R-$b.R)
			$dg = [math]::Abs($a.G-$b.G)
			$db = [math]::Abs($a.B-$b.B)
			$delta = $dr + $dg + $db
			$absolute += $delta
			$maxChannel = [math]::Max($maxChannel,[math]::Max($dr,[math]::Max($dg,$db)))
			if ($delta -eq 0) {
				$exact++
			} else {
				$minX = [math]::Min($minX,$x)
				$minY = [math]::Min($minY,$y)
				$maxX = [math]::Max($maxX,$x)
				$maxY = [math]::Max($maxY,$y)
			}
		}
	}

	if ($OrientedOutput) {
		$out = if ([IO.Path]::IsPathRooted($OrientedOutput)) {
			[IO.Path]::GetFullPath($OrientedOutput)
		} else {
			[IO.Path]::GetFullPath((Join-Path (Get-Location) $OrientedOutput))
		}
		$core.Save($out,[Drawing.Imaging.ImageFormat]::Png)
	}

	$pixels = $core.Width * $core.Height
	[PSCustomObject]@{
		Set = $SetName
		Width = $core.Width
		Height = $core.Height
		ExactPixels = $exact
		ExactPercent = [math]::Round(100.0*$exact/$pixels,3)
		MeanAbsoluteErrorPerChannel = [math]::Round($absolute/(3.0*$pixels),4)
		MaxChannelError = $maxChannel
		DifferenceBounds = if ($maxX -ge 0) { "$minX,$minY-$maxX,$maxY" } else { "none" }
	}
}
finally {
	$core.Dispose()
	$reference.Dispose()
}
