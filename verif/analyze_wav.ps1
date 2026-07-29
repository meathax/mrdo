param(
	[Parameter(Mandatory=$true)][string]$Path,
	[double]$SkipStartSeconds = 0
)

$ErrorActionPreference = "Stop"
$resolved = (Resolve-Path $Path).Path
$bytes = [IO.File]::ReadAllBytes($resolved)
if ($bytes.Length -lt 44 -or [Text.Encoding]::ASCII.GetString($bytes,0,4) -ne "RIFF" -or
	[Text.Encoding]::ASCII.GetString($bytes,8,4) -ne "WAVE") {
	throw "Not a RIFF/WAVE file: $resolved"
}

$offset = 12
$format = $null
$channels = 0
$sampleRate = 0
$bits = 0
$dataOffset = -1
$dataSize = 0
while (($offset + 8) -le $bytes.Length) {
	$chunk = [Text.Encoding]::ASCII.GetString($bytes,$offset,4)
	$size = [BitConverter]::ToUInt32($bytes,$offset+4)
	$body = $offset + 8
	if (($body + $size) -gt $bytes.Length) { throw "Truncated WAV chunk $chunk in $resolved" }
	if ($chunk -eq "fmt ") {
		$format = [BitConverter]::ToUInt16($bytes,$body)
		$channels = [BitConverter]::ToUInt16($bytes,$body+2)
		$sampleRate = [BitConverter]::ToUInt32($bytes,$body+4)
		$bits = [BitConverter]::ToUInt16($bytes,$body+14)
	} elseif ($chunk -eq "data") {
		$dataOffset = $body
		$dataSize = $size
		break
	}
	$offset = $body + $size + ($size -band 1)
}
if ($format -ne 1 -or $bits -ne 16 -or $channels -lt 1 -or $dataOffset -lt 0) {
	throw "Only PCM16 WAV is supported: format=$format channels=$channels bits=$bits"
}

$totalSampleCount = [int]($dataSize / 2)
$firstSample = [int][math]::Min($totalSampleCount,
	[math]::Max(0,[math]::Floor($SkipStartSeconds*$sampleRate*$channels)))
$sampleCount = $totalSampleCount - $firstSample
[double]$sum = 0
[double]$sumSquares = 0
[int]$peak = 0
[long]$zeros = 0
[long]$clipped = 0
for ($index=$firstSample; $index -lt $totalSampleCount; $index++) {
	$value = [BitConverter]::ToInt16($bytes,$dataOffset + 2*$index)
	$magnitude = [math]::Abs([int]$value)
	if ($magnitude -gt $peak) { $peak = $magnitude }
	if ($value -eq 0) { $zeros++ }
	if ($magnitude -ge 32767) { $clipped++ }
	$sum += $value
	$sumSquares += [double]$value * [double]$value
}
$rms = if ($sampleCount) { [math]::Sqrt($sumSquares/$sampleCount) } else { 0 }
$dbFloor = -200.0
$peakDb = if ($peak) { 20.0*[math]::Log10($peak/32768.0) } else { $dbFloor }
$rmsDb = if ($rms) { 20.0*[math]::Log10($rms/32768.0) } else { $dbFloor }

[PSCustomObject]@{
	Path = $resolved
	Channels = $channels
	SampleRate = $sampleRate
	BitsPerSample = $bits
	Frames = [long]($sampleCount/$channels)
	DurationSeconds = [math]::Round(($sampleCount/$channels)/[double]$sampleRate,6)
	SkippedStartSeconds = $SkipStartSeconds
	Peak = $peak
	PeakDbFS = [math]::Round($peakDb,3)
	Rms = [math]::Round($rms,3)
	RmsDbFS = [math]::Round($rmsDb,3)
	DcOffset = [math]::Round($sum/$sampleCount,3)
	ZeroPercent = [math]::Round(100.0*$zeros/$sampleCount,3)
	ClippedSamples = $clipped
}
