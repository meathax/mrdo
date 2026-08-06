param(
	[string]$Manifest = (Join-Path $PSScriptRoot "romsets.json"),
	[string]$MraDirectory = (Join-Path (Split-Path -Parent $PSScriptRoot) "releases"),
	[string]$RomImageDirectory = (Join-Path (Split-Path -Parent $PSScriptRoot) "verif\out")
)

$ErrorActionPreference = "Stop"
$definition = Get-Content -LiteralPath $Manifest -Raw | ConvertFrom-Json
$seenIds = @{}

function Get-ExpectedControls([string]$SetName) {
	$systemControls = "Start 1P,Start 2P,Coin 1,Coin 2,Service Mode,Pause"
	$standardDefaults = "A,-,Start,Select,R,L,X,Y,-,-,-,-,-"
	$soccerDefaults = "A,B,Start,Select,R,L,X,Y,-,-,-,-,-"
	$unusedRightStick = "-,-,-,-"
	switch ($SetName) {
		"docastle" { return @{ names="Hammer,-,$systemControls,$unusedRightStick,Service Credit"; defaults=$standardDefaults; count="1" } }
		"douni"    { return @{ names="Hammer,-,$systemControls,$unusedRightStick,Service Credit"; defaults=$standardDefaults; count="1" } }
		"dorunrun" { return @{ names="Throw,-,$systemControls,$unusedRightStick,Service Credit"; defaults=$standardDefaults; count="1" } }
		"spiero"   { return @{ names="Throw,-,$systemControls,$unusedRightStick,Service Credit"; defaults=$standardDefaults; count="1" } }
		"dowild"   { return @{ names="Speed,-,$systemControls,$unusedRightStick,Service Credit"; defaults=$standardDefaults; count="1" } }
		"jjack"    { return @{ names="Action,-,$systemControls,$unusedRightStick,Service Credit"; defaults=$standardDefaults; count="1" } }
		"kickridr" { return @{ names="Accelerate,-,$systemControls,$unusedRightStick,Service Credit"; defaults=$standardDefaults; count="1" } }
		"idsoccer" { return @{ names="Kick,Change Player,$systemControls,Right Stick Left,Right Stick Right,Right Stick Up,Right Stick Down,Service Credit"; defaults=$soccerDefaults; count="2" } }
		"asoccer"  { return @{ names="Kick,Change Player,$systemControls,Right Stick Left,Right Stick Right,Right Stick Up,Right Stick Down,Service Credit"; defaults=$soccerDefaults; count="2" } }
	}
	throw "No expected control definition for $SetName"
}

foreach ($game in $definition.sets) {
	$fileName = ($game.name -replace '[<>:"/\\|?*]', '_') + ".mra"
	$mraPath = Join-Path $MraDirectory $fileName
	if (-not (Test-Path -LiteralPath $mraPath)) {
		throw "Missing MRA: $mraPath"
	}
	[xml]$xml = Get-Content -LiteralPath $mraPath -Raw
	$root = $xml.misterromdescription

	if ($root.rbf -ne "Arcade-DoCastle") {
		throw "$fileName selects '$($root.rbf)' instead of Arcade-DoCastle"
	}
	if ($root.resolution -ne "15kHz") {
		throw "$fileName resolution '$($root.resolution)' should be the standard 15kHz arcade-CRT class, not a pixel size"
	}
	if ($root.homebrew -ne "no") {
		throw "$fileName homebrew '$($root.homebrew)' should be 'no' per the MiSTer-devel MRA convention"
	}
	if ($root.bootleg -ne "no") {
		throw "$fileName bootleg '$($root.bootleg)' should be 'no' per the MiSTer-devel MRA convention"
	}
	if ($root.setname -ne $game.set) {
		throw "$fileName setname '$($root.setname)' does not match $($game.set)"
	}
	if ($root.rotation -ne $game.rotation) {
		throw "$fileName rotation '$($root.rotation)' does not match $($game.rotation)"
	}
	if ($root.switches.default -ne "$($game.dsw1),$($game.dsw2)") {
		throw "$fileName DIP default '$($root.switches.default)' is wrong"
	}
	$controls = Get-ExpectedControls $game.set
	if ($root.players -ne "2") {
		throw "$fileName players '$($root.players)' is wrong"
	}
	if ($root.num_buttons -ne $controls.count) {
		throw "$fileName num_buttons '$($root.num_buttons)' should be '$($controls.count)'"
	}
	if ($root.buttons.names -ne $controls.names) {
		throw "$fileName control names '$($root.buttons.names)' do not match the per-game profile"
	}
	if ($root.buttons.default -ne $controls.defaults) {
		throw "$fileName default controls '$($root.buttons.default)' should be '$($controls.defaults)'"
	}
	$controlFields = @(([string]$root.buttons.names) -split ',')
	if ($controlFields.Count -ne 13) {
		throw "$fileName has $($controlFields.Count) control fields instead of the fixed ABI's 13"
	}
	$isSoccer = $game.profile -eq "soccer"
	$rightStickFields = $controlFields[8..11]
	if ($isSoccer -and ($rightStickFields -contains "-")) {
		throw "$fileName must expose all four right-stick directions"
	}
	if (-not $isSoccer -and (@($rightStickFields | Where-Object { $_ -ne "-" }).Count -ne 0)) {
		throw "$fileName exposes right-stick directions for a game that does not use them"
	}

	$rom0 = @($root.rom | Where-Object { $_.index -eq "0" })
	$rom1 = @($root.rom | Where-Object { $_.index -eq "1" })
	if ($rom0.Count -ne 1 -or $rom1.Count -ne 1) {
		throw "$fileName must contain exactly one index-0 and one index-1 ROM"
	}
	if ($rom0[0].zip -ne $game.zip) {
		throw "$fileName points to '$($rom0[0].zip)' instead of $($game.zip)"
	}
	if ($rom0[0].GetAttribute("type")) {
		throw "$fileName ROM index-0 has a 'type' attribute; the current MiSTer-devel MRA convention omits it"
	}

	$expectedId = "{0:X2}" -f [int]$game.id
	$actualId = ([string]$rom1[0].part).Trim()
	if ($actualId -ne $expectedId) {
		throw "$fileName game ID '$actualId' does not match $expectedId"
	}
	if ($seenIds.ContainsKey($actualId)) {
		throw "Duplicate game ID $actualId in $fileName and $($seenIds[$actualId])"
	}
	$seenIds[$actualId] = $fileName

	$romImage = Join-Path $RomImageDirectory "$($game.set).rom"
	$expectedMd5 = (Get-FileHash -LiteralPath $romImage -Algorithm MD5).Hash.ToLowerInvariant()
	if ($rom0[0].md5 -ne $expectedMd5) {
		throw "$fileName MD5 '$($rom0[0].md5)' does not match $expectedMd5"
	}

	$partByName = @{}
	foreach ($part in $game.parts) {
		$partByName[$part.name] = $part
	}
	$cursor = 0
	foreach ($partNode in @($rom0[0].part)) {
		$partName = $partNode.GetAttribute("name")
		$repeat = $partNode.GetAttribute("repeat")
		if ($partName) {
			if (-not $partByName.ContainsKey($partName)) {
				throw "$fileName contains unknown ROM $partName"
			}
			$expected = $partByName[$partName]
			if ($cursor -ne [int]$expected.streamOffset) {
				throw "$fileName places $partName at $cursor, expected $($expected.streamOffset)"
			}
			if ($partNode.GetAttribute("crc") -ne [string]$expected.crc32) {
				throw "$fileName CRC for $partName is wrong"
			}
			$cursor += [int]$expected.length
		} elseif ($repeat) {
			if (([string]$partNode.InnerText).Trim() -ne "00") {
				throw "$fileName contains a non-zero fill"
			}
			$cursor += [int]$repeat
		} else {
			throw "$fileName contains an unrecognized index-0 part"
		}
	}
	if ($cursor -ne [int]$definition.imageSize) {
		throw "$fileName index-0 stream is $cursor bytes, expected $($definition.imageSize)"
	}
	Write-Host ("PASS {0,-24} id={1} bytes={2} md5={3}" -f $game.set,$expectedId,$cursor,$expectedMd5)
}

if ($seenIds.Count -ne $definition.sets.Count) {
	throw "Validated $($seenIds.Count) unique IDs for $($definition.sets.Count) games"
}
Write-Host "Validated $($definition.sets.Count) Arcade-DoCastle MRAs."
