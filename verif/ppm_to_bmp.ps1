param(
	[Parameter(Mandatory=$true)][string]$InputPath,
	[Parameter(Mandatory=$true)][string]$OutputPath
)
$ErrorActionPreference = "Stop"
$src = [IO.File]::ReadAllBytes((Resolve-Path $InputPath))
$header = [Text.Encoding]::ASCII.GetBytes("P6`n240 192`n255`n")
$pixOff = $header.Length
$w = 240
$h = 192
$row = $w * 3
$fileSize = 54 + $row * $h
$bmp = New-Object byte[] $fileSize
$bmp[0] = 0x42
$bmp[1] = 0x4d
[BitConverter]::GetBytes($fileSize).CopyTo($bmp,2)
[BitConverter]::GetBytes(54).CopyTo($bmp,10)
[BitConverter]::GetBytes(40).CopyTo($bmp,14)
[BitConverter]::GetBytes($w).CopyTo($bmp,18)
[BitConverter]::GetBytes($h).CopyTo($bmp,22)
[BitConverter]::GetBytes([int16]1).CopyTo($bmp,26)
[BitConverter]::GetBytes([int16]24).CopyTo($bmp,28)
[BitConverter]::GetBytes($row*$h).CopyTo($bmp,34)
for ($y=0; $y -lt $h; $y++) {
	$sy = $h - 1 - $y
	for ($x=0; $x -lt $w; $x++) {
		$s = $pixOff + ($sy*$w+$x)*3
		$d = 54 + ($y*$w+$x)*3
		$bmp[$d]   = $src[$s+2]
		$bmp[$d+1] = $src[$s+1]
		$bmp[$d+2] = $src[$s]
	}
}
$resolvedOut = if ([IO.Path]::IsPathRooted($OutputPath)) {
	[IO.Path]::GetFullPath($OutputPath)
} else {
	[IO.Path]::GetFullPath((Join-Path (Get-Location) $OutputPath))
}
[IO.File]::WriteAllBytes($resolvedOut,$bmp)
Get-Item -LiteralPath $resolvedOut
