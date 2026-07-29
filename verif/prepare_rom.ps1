param(
	[ValidateNotNullOrEmpty()]
	[string]$SetName = "docastle",
	[string]$Manifest = (Join-Path (Split-Path -Parent $PSScriptRoot) "scripts\romsets.json"),
	[string]$OutputDirectory = (Join-Path $PSScriptRoot "out")
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.IO.Compression.FileSystem

function New-Crc32Table {
	$table = New-Object 'System.UInt32[]' 256
	[uint32]$polynomial = [uint32]::Parse(
		"edb88320",
		[Globalization.NumberStyles]::HexNumber
	)
	for ($index = 0; $index -lt 256; $index++) {
		[uint32]$value = $index
		for ($bit = 0; $bit -lt 8; $bit++) {
			if (($value -band 1) -ne 0) {
				$value = [uint32]($polynomial -bxor ($value -shr 1))
			} else {
				$value = [uint32]($value -shr 1)
			}
		}
		$table[$index] = $value
	}
	return ,$table
}

function Get-Crc32Hex([byte[]]$Bytes, [uint32[]]$Table) {
	[uint32]$allOnes = [uint32]::MaxValue
	[uint32]$crc = $allOnes
	foreach ($byte in $Bytes) {
		$lookup = ($crc -bxor [uint32]$byte) -band 0xff
		$crc = [uint32](($crc -shr 8) -bxor $Table[$lookup])
	}
	$crc = [uint32]($crc -bxor $allOnes)
	return $crc.ToString("x8")
}

function Get-HashHex([byte[]]$Bytes, [string]$Algorithm) {
	$hasher = [Security.Cryptography.HashAlgorithm]::Create($Algorithm)
	try {
		return ([BitConverter]::ToString($hasher.ComputeHash($Bytes)) -replace '-', '').ToLowerInvariant()
	} finally {
		$hasher.Dispose()
	}
}

function Read-ZipEntryBytes([IO.Compression.ZipArchiveEntry]$Entry) {
	$entryStream = $Entry.Open()
	$memory = [IO.MemoryStream]::new()
	try {
		$entryStream.CopyTo($memory)
		return $memory.ToArray()
	} finally {
		$memory.Dispose()
		$entryStream.Dispose()
	}
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$manifestPath = [IO.Path]::GetFullPath($Manifest)
$outputPath = [IO.Path]::GetFullPath($OutputDirectory)
$definition = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json

if ($definition.schema -ne 1) {
	throw "Unsupported ROM manifest schema $($definition.schema)"
}
if ($definition.imageSize -ne 0x48400) {
	throw "Manifest image size is $($definition.imageSize), expected 0x48400"
}

$requested = if ($SetName -eq "all") {
	@($definition.sets)
} else {
	@($definition.sets | Where-Object { $_.set -eq $SetName })
}
if ($requested.Count -eq 0) {
	throw "Unknown set '$SetName'. Valid sets: $($definition.sets.set -join ', ')"
}

New-Item -ItemType Directory -Force -Path $outputPath | Out-Null
$crcTable = New-Crc32Table
$summaries = @()

foreach ($game in $requested) {
	$zipPath = Join-Path $projectRoot $game.zip
	$zipHash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA1).Hash.ToLowerInvariant()
	if ($zipHash -ne $game.zipSha1) {
		throw "$($game.zip) SHA-1 $zipHash does not match manifest $($game.zipSha1)"
	}

	$image = New-Object byte[] ([int]$definition.imageSize)
	$written = New-Object bool[] ([int]$definition.imageSize)
	$archive = [IO.Compression.ZipFile]::OpenRead($zipPath)
	try {
		$entries = @{}
		foreach ($entry in $archive.Entries) {
			$entries[$entry.FullName.ToLowerInvariant()] = $entry
		}

		foreach ($part in $game.parts) {
			$key = $part.name.ToLowerInvariant()
			if (-not $entries.ContainsKey($key)) {
				throw "$($game.zip) is missing $($part.name)"
			}
			$bytes = Read-ZipEntryBytes $entries[$key]
			if ($bytes.Length -ne $part.length) {
				throw "$($game.set)/$($part.name) has $($bytes.Length) bytes, expected $($part.length)"
			}

			$crc = Get-Crc32Hex $bytes $crcTable
			if ($crc -ne $part.crc32) {
				throw "$($game.set)/$($part.name) CRC32 $crc does not match $($part.crc32)"
			}
			$sha1 = Get-HashHex $bytes "SHA1"
			if ($sha1 -ne $part.sha1) {
				throw "$($game.set)/$($part.name) SHA-1 $sha1 does not match $($part.sha1)"
			}

			$offset = [int]$part.streamOffset
			if (($offset + $bytes.Length) -gt $image.Length) {
				throw "$($game.set)/$($part.name) exceeds the fixed image"
			}
			for ($byteIndex = 0; $byteIndex -lt $bytes.Length; $byteIndex++) {
				if ($written[$offset + $byteIndex]) {
					throw "$($game.set)/$($part.name) overlaps a previous ROM at stream offset $($offset + $byteIndex)"
				}
				$written[$offset + $byteIndex] = $true
			}
			[Array]::Copy($bytes, 0, $image, $offset, $bytes.Length)
		}
	} finally {
		$archive.Dispose()
	}

	$outFile = Join-Path $outputPath "$($game.set).rom"
	[IO.File]::WriteAllBytes($outFile, $image)
	$summaries += [PSCustomObject][ordered]@{
		id = [int]$game.id
		set = $game.set
		profile = $game.profile
		path = $outFile
		bytes = $image.Length
		md5 = Get-HashHex $image "MD5"
		sha1 = Get-HashHex $image "SHA1"
	}
}

$summaryFile = Join-Path $outputPath "rom-images.json"
[IO.File]::WriteAllText(
	$summaryFile,
	(($summaries | ConvertTo-Json -Depth 4) + [Environment]::NewLine)
)
$summaries | Format-Table id,set,profile,bytes,md5,sha1 -AutoSize
Write-Host "Wrote $summaryFile"
