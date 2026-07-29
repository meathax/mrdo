param(
	[string]$MameDriver = $env:MAME_DOCASTLE_DRIVER,
	[string]$Output = (Join-Path $PSScriptRoot "romsets.json"),
	[string]$ProjectRoot = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($MameDriver) -or -not (Test-Path -LiteralPath $MameDriver)) {
	throw "Pass -MameDriver <path-to-mame/src/mame/universal/docastle.cpp> or set MAME_DOCASTLE_DRIVER."
}

function Convert-MameNumber([string]$Text) {
	if ($Text -match '^0x') {
		return [Convert]::ToInt32($Text.Substring(2), 16)
	}
	return [int]$Text
}

$slotMap = @{
	maincpu   = @{ Base = 0x00000; Size = 0x10000 }
	subcpu    = @{ Base = 0x10000; Size = 0x04000 }
	spritecpu = @{ Base = 0x14000; Size = 0x00200 }
	gfx1      = @{ Base = 0x14200; Size = 0x04000 }
	gfx2      = @{ Base = 0x18200; Size = 0x20000 }
	adpcm     = @{ Base = 0x38200; Size = 0x10000 }
	proms     = @{ Base = 0x48200; Size = 0x00200 }
}

$selected = @(
	[ordered]@{ id=0; set="docastle"; zip="docastle.zip"; name="Mr. Do's Castle"; profile="castle"; rotation="vertical (ccw)"; dsw1="DF"; dsw2="FF" },
	[ordered]@{ id=1; set="douni"; zip="douni.zip"; name="Mr. Do! vs. Unicorns"; profile="castle"; rotation="vertical (ccw)"; dsw1="DF"; dsw2="FF" },
	[ordered]@{ id=2; set="dorunrun"; zip="dorunrun.zip"; name="Do! Run Run"; profile="runrun"; rotation="horizontal"; dsw1="DF"; dsw2="FF" },
	[ordered]@{ id=3; set="dowild"; zip="dowild.zip"; name="Mr. Do's Wild Ride"; profile="runrun"; rotation="horizontal"; dsw1="DF"; dsw2="FF" },
	[ordered]@{ id=4; set="jjack"; zip="jjack.zip"; name="Jumping Jack"; profile="runrun"; rotation="vertical (ccw)"; dsw1="DF"; dsw2="FF" },
	[ordered]@{ id=5; set="kickridr"; zip="kickridr.zip"; name="Kick Rider"; profile="runrun"; rotation="horizontal"; dsw1="DF"; dsw2="FF" },
	[ordered]@{ id=6; set="spiero"; zip="spiero.zip"; name="Super Pierrot"; profile="runrun"; rotation="horizontal"; dsw1="DF"; dsw2="FF" },
	[ordered]@{ id=7; set="idsoccer"; zip="idsoccer.zip"; name="Indoor Soccer"; profile="soccer"; rotation="horizontal"; dsw1="FF"; dsw2="FF" },
	[ordered]@{ id=8; set="asoccer"; zip="asoccer.zip"; name="American Soccer"; profile="soccer"; rotation="horizontal"; dsw1="FF"; dsw2="FF" }
)

$source = Get-Content -LiteralPath $MameDriver -Raw
$sets = @()

foreach ($game in $selected) {
	$escapedSet = [Regex]::Escape($game.set)
	$blockMatch = [Regex]::Match(
		$source,
		"(?s)ROM_START\(\s*$escapedSet\s*\)(.*?)ROM_END"
	)
	if (-not $blockMatch.Success) {
		throw "ROM_START block not found for $($game.set)"
	}

	$currentRegion = $null
	$parts = @()
	foreach ($line in ($blockMatch.Groups[1].Value -split "\r?\n")) {
		$regionMatch = [Regex]::Match(
			$line,
			'ROM_REGION\(\s*(0x[0-9a-fA-F]+|[0-9]+)\s*,\s*"([^"]+)"'
		)
		if ($regionMatch.Success) {
			$currentRegion = $regionMatch.Groups[2].Value
			if (-not $slotMap.ContainsKey($currentRegion)) {
				throw "Unsupported region '$currentRegion' in $($game.set)"
			}
			continue
		}

		$loadMatch = [Regex]::Match(
			$line,
			'ROM_LOAD\(\s*"([^"]+)"\s*,\s*(0x[0-9a-fA-F]+|[0-9]+)\s*,\s*(0x[0-9a-fA-F]+|[0-9]+)\s*,\s*(?:BAD_DUMP\s+)?CRC\(([0-9a-fA-F]+)\)\s+SHA1\(([0-9a-fA-F]+)\)'
		)
		if ($loadMatch.Success) {
			if (-not $currentRegion) {
				throw "ROM_LOAD without ROM_REGION in $($game.set)"
			}
			$regionOffset = Convert-MameNumber $loadMatch.Groups[2].Value
			$length = Convert-MameNumber $loadMatch.Groups[3].Value
			$slot = $slotMap[$currentRegion]
			if (($regionOffset + $length) -gt $slot.Size) {
				throw "$($game.set)/$($loadMatch.Groups[1].Value) exceeds fixed $currentRegion slot"
			}
			$parts += [ordered]@{
				name = $loadMatch.Groups[1].Value
				region = $currentRegion
				regionOffset = $regionOffset
				streamOffset = $slot.Base + $regionOffset
				length = $length
				crc32 = $loadMatch.Groups[4].Value.ToLowerInvariant()
				sha1 = $loadMatch.Groups[5].Value.ToLowerInvariant()
			}
		}
	}

	$zipPath = Join-Path $ProjectRoot $game.zip
	if (-not (Test-Path -LiteralPath $zipPath)) {
		throw "Supplied archive missing: $zipPath"
	}

	$sets += [ordered]@{
		id = $game.id
		set = $game.set
		zip = $game.zip
		zipSha1 = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA1).Hash.ToLowerInvariant()
		name = $game.name
		profile = $game.profile
		rotation = $game.rotation
		dsw1 = $game.dsw1
		dsw2 = $game.dsw2
		parts = $parts
	}
}

$document = [ordered]@{
	schema = 1
	mameDriver = "src/mame/universal/docastle.cpp"
	mameRevision = "affe701f9210d003d2cc5eff311f94053afa679b"
	imageSize = 0x48400
	slots = [ordered]@{
		maincpu   = [ordered]@{ offset=0x00000; size=0x10000 }
		subcpu    = [ordered]@{ offset=0x10000; size=0x04000 }
		spritecpu = [ordered]@{ offset=0x14000; size=0x00200 }
		gfx1      = [ordered]@{ offset=0x14200; size=0x04000 }
		gfx2      = [ordered]@{ offset=0x18200; size=0x20000 }
		adpcm     = [ordered]@{ offset=0x38200; size=0x10000 }
		proms     = [ordered]@{ offset=0x48200; size=0x00200 }
	}
	sets = $sets
}

$json = $document | ConvertTo-Json -Depth 10
[IO.File]::WriteAllText([IO.Path]::GetFullPath($Output), $json + [Environment]::NewLine)
Write-Host "Wrote $Output with $($sets.Count) sets."
