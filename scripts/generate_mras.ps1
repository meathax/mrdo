param(
	[string]$Manifest = (Join-Path $PSScriptRoot "romsets.json"),
	[string]$RomImageDirectory = (Join-Path (Split-Path -Parent $PSScriptRoot) "verif\out"),
	[string]$OutputDirectory = (Join-Path (Split-Path -Parent $PSScriptRoot) "releases")
)

$ErrorActionPreference = "Stop"

function Escape-Xml([string]$Text) {
	return [Security.SecurityElement]::Escape($Text)
}

function Get-CommonCoinDips {
	return @(
		'		<dip bits="8,9,10,11" name="Coin B" ids="Free,1/1,1/1,1/1,1/1,1/1,4/1,3/2,3/1,2/3,2/1,1/5,1/4,1/3,1/2,1/1"/>',
		'		<dip bits="12,13,14,15" name="Coin A" ids="Free,1/1,1/1,1/1,1/1,1/1,4/1,3/2,3/1,2/3,2/1,1/5,1/4,1/3,1/2,1/1"/>'
	)
}

function Get-SoccerCoinDips {
	return @(
		'		<dip bits="8,9,10,11" name="Coin B" ids="Free,1/1,1/1,1/1,1/1,4/1,3/2,3/1,2/3,2/1,1/6,1/5,1/4,1/3,1/2,1/1"/>',
		'		<dip bits="12,13,14,15" name="Coin A" ids="Free,1/1,1/1,1/1,1/1,4/1,3/2,3/1,2/3,2/1,1/6,1/5,1/4,1/3,1/2,1/1"/>'
	)
}

function Get-DipLines([string]$SetName) {
	$lines = @('		<dip bits="0,1" name="Difficulty" ids="Hardest,Hard,Medium,Easy"/>')
	switch ($SetName) {
		"docastle" {
			$lines += '		<dip bits="2" name="Rack Test" ids="On,Off"/>'
			$lines += '		<dip bits="3" name="Bonus Credit for Diamond" ids="No,Yes"/>'
			$lines += '		<dip bits="4" name="Difficulty of EXTRA" ids="Difficult,Easy"/>'
			$lines += '		<dip bits="5" name="Cabinet" ids="Upright,Cocktail"/>'
			$lines += '		<dip bits="6,7" name="Lives" ids="2,5,4,3"/>'
			$lines += Get-CommonCoinDips
		}
		"douni" {
			$lines += '		<dip bits="2" name="Rack Test" ids="On,Off"/>'
			$lines += '		<dip bits="3" name="Bonus Credit for Diamond" ids="No,Yes"/>'
			$lines += '		<dip bits="4" name="Difficulty of EXTRA" ids="Difficult,Easy"/>'
			$lines += '		<dip bits="5" name="Cabinet" ids="Upright,Cocktail"/>'
			$lines += '		<dip bits="6,7" name="Lives" ids="2,5,4,3"/>'
			$lines += Get-CommonCoinDips
		}
		"dorunrun" {
			$lines += '		<dip bits="2" name="Demo Sounds" ids="Off,On"/>'
			$lines += '		<dip bits="3" name="Flip Screen" ids="On,Off"/>'
			$lines += '		<dip bits="4" name="Difficulty of EXTRA" ids="Difficult,Easy"/>'
			$lines += '		<dip bits="5" name="Cabinet" ids="Upright,Cocktail"/>'
			$lines += '		<dip bits="6" name="Special" ids="Not Given,Given"/>'
			$lines += '		<dip bits="7" name="Lives" ids="5,3"/>'
			$lines += Get-CommonCoinDips
		}
		"spiero" {
			$lines += '		<dip bits="2" name="Demo Sounds" ids="Off,On"/>'
			$lines += '		<dip bits="3" name="Flip Screen" ids="On,Off"/>'
			$lines += '		<dip bits="4" name="Difficulty of EXTRA" ids="Difficult,Easy"/>'
			$lines += '		<dip bits="5" name="Cabinet" ids="Upright,Cocktail"/>'
			$lines += '		<dip bits="6" name="Special" ids="Not Given,Given"/>'
			$lines += '		<dip bits="7" name="Lives" ids="5,3"/>'
			$lines += Get-CommonCoinDips
		}
		"dowild" {
			$lines += '		<dip bits="2" name="Rack Test" ids="On,Off"/>'
			$lines += '		<dip bits="3" name="Flip Screen" ids="On,Off"/>'
			$lines += '		<dip bits="4" name="Difficulty of EXTRA" ids="Difficult,Easy"/>'
			$lines += '		<dip bits="5" name="Cabinet" ids="Upright,Cocktail"/>'
			$lines += '		<dip bits="6" name="Special" ids="Not Given,Given"/>'
			$lines += '		<dip bits="7" name="Lives" ids="5,3"/>'
			$lines += Get-CommonCoinDips
		}
		"jjack" {
			$lines += '		<dip bits="2" name="Rack Test" ids="On,Off"/>'
			$lines += '		<dip bits="3" name="Flip Screen" ids="On,Off"/>'
			$lines += '		<dip bits="4" name="Extra" ids="Hard,Easy"/>'
			$lines += '		<dip bits="5" name="Cabinet" ids="Upright,Cocktail"/>'
			$lines += '		<dip bits="6,7" name="Lives" ids="2,5,4,3"/>'
			$lines += Get-CommonCoinDips
		}
		"kickridr" {
			$lines += '		<dip bits="2" name="Rack Test" ids="On,Off"/>'
			$lines += '		<dip bits="3" name="Flip Screen" ids="On,Off"/>'
			$lines += '		<dip bits="4" name="Unknown SWA:4" ids="On,Off"/>'
			$lines += '		<dip bits="5" name="Cabinet" ids="Upright,Cocktail"/>'
			$lines += '		<dip bits="6" name="Unknown SWA:2" ids="On,Off"/>'
			$lines += '		<dip bits="7" name="Unknown SWA:1" ids="On,Off"/>'
			$lines += Get-CommonCoinDips
		}
		"idsoccer" {
			$lines += '		<dip bits="2" name="Continuity" ids="No,Yes"/>'
			$lines += '		<dip bits="3" name="Flip Screen" ids="On,Off"/>'
			$lines += '		<dip bits="4" name="Allow Continue (2P)" ids="No,Yes"/>'
			$lines += '		<dip bits="5" name="Allow Continue (1P)" ids="No,Yes"/>'
			$lines += '		<dip bits="6,7" name="Real Game Time" ids="1:00,2:00,2:30,3:00"/>'
			$lines += Get-SoccerCoinDips
		}
		"asoccer" {
			$lines += '		<dip bits="2" name="Joysticks" ids="Single,Dual"/>'
			$lines += '		<dip bits="3" name="Flip Screen" ids="On,Off"/>'
			$lines += '		<dip bits="4" name="Unknown SWA:4" ids="On,Off"/>'
			$lines += '		<dip bits="5" name="Demo Sounds" ids="Off,On"/>'
			$lines += '		<dip bits="6,7" name="Real Game Time" ids="1:00,2:00,2:30,3:00"/>'
			$lines += Get-SoccerCoinDips
		}
		default { throw "No DIP definition for $SetName" }
	}
	return $lines
}

function Get-SetMetadata([string]$SetName) {
	switch ($SetName) {
		"docastle" { return @{ year=1983; region="World"; parent="docastle"; category="Platform" } }
		"douni"    { return @{ year=1983; region="Japan"; parent="docastle"; category="Platform" } }
		"dorunrun" { return @{ year=1984; region="World"; parent="dorunrun"; category="Maze" } }
		"dowild"   { return @{ year=1984; region="World"; parent="dowild"; category="Driving" } }
		"jjack"    { return @{ year=1984; region="World"; parent="jjack"; category="Platform" } }
		"kickridr" { return @{ year=1984; region="World"; parent="kickridr"; category="Driving" } }
		"spiero"   { return @{ year=1987; region="Japan"; parent="dorunrun"; category="Platform" } }
		"idsoccer" { return @{ year=1985; region="World"; parent="idsoccer"; category="Sports" } }
		"asoccer"  { return @{ year=1987; region="Japan"; parent="idsoccer"; category="Sports" } }
	}
	throw "No metadata for $SetName"
}

function Get-ControlMetadata([string]$SetName) {
	# Keep all thirteen names aligned with the shared core's fixed joystick bit ABI.
	# A dash hides an input in MiSTer's mapper without shifting later bit positions.
	$systemControls = "Start 1P,Start 2P,Coin 1,Coin 2,Service Mode,Pause"
	$standardDefaults = "A,-,Start,Select,R,L,X,Y,-,-,-,-,-"
	$soccerDefaults = "A,B,Start,Select,R,L,X,Y,-,-,-,-,-"
	$unusedRightStick = "-,-,-,-"
	switch ($SetName) {
		"docastle" { return @{ names="Hammer,-,$systemControls,$unusedRightStick,Service Credit"; defaults=$standardDefaults; count=1 } }
		"douni"    { return @{ names="Hammer,-,$systemControls,$unusedRightStick,Service Credit"; defaults=$standardDefaults; count=1 } }
		"dorunrun" { return @{ names="Throw,-,$systemControls,$unusedRightStick,Service Credit"; defaults=$standardDefaults; count=1 } }
		"spiero"   { return @{ names="Throw,-,$systemControls,$unusedRightStick,Service Credit"; defaults=$standardDefaults; count=1 } }
		"dowild"   { return @{ names="Speed,-,$systemControls,$unusedRightStick,Service Credit"; defaults=$standardDefaults; count=1 } }
		"jjack"    { return @{ names="Action,-,$systemControls,$unusedRightStick,Service Credit"; defaults=$standardDefaults; count=1 } }
		"kickridr" { return @{ names="Accelerate,-,$systemControls,$unusedRightStick,Service Credit"; defaults=$standardDefaults; count=1 } }
		"idsoccer" { return @{ names="Kick,Change Player,$systemControls,Right Stick Left,Right Stick Right,Right Stick Up,Right Stick Down,Service Credit"; defaults=$soccerDefaults; count=2 } }
		"asoccer"  { return @{ names="Kick,Change Player,$systemControls,Right Stick Left,Right Stick Right,Right Stick Up,Right Stick Down,Service Credit"; defaults=$soccerDefaults; count=2 } }
	}
	throw "No control definition for $SetName"
}

$definition = Get-Content -LiteralPath $Manifest -Raw | ConvertFrom-Json
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

foreach ($game in $definition.sets) {
	$romImage = Join-Path $RomImageDirectory "$($game.set).rom"
	if (-not (Test-Path -LiteralPath $romImage)) {
		throw "Packed ROM missing: $romImage. Run verif/prepare_rom.ps1 -SetName all first."
	}
	if ((Get-Item -LiteralPath $romImage).Length -ne $definition.imageSize) {
		throw "$romImage has the wrong fixed-ABI length"
	}
	$md5 = (Get-FileHash -LiteralPath $romImage -Algorithm MD5).Hash.ToLowerInvariant()
	$meta = Get-SetMetadata $game.set
	$isSoccer = $game.profile -eq "soccer"
	$controls = Get-ControlMetadata $game.set
	$buttonNames = $controls.names
	if (@($buttonNames -split ',').Count -ne 13) {
		throw "$($game.set) must define exactly 13 fixed-ABI control names"
	}

	$builder = [Text.StringBuilder]::new()
	[void]$builder.AppendLine("<misterromdescription>")
	[void]$builder.AppendLine("	<name>$(Escape-Xml $game.name)</name>")
	[void]$builder.AppendLine("	<region>$($meta.region)</region>")
	[void]$builder.AppendLine("	<homebrew>no</homebrew>")
	[void]$builder.AppendLine("	<bootleg>no</bootleg>")
	[void]$builder.AppendLine("	<platform>Universal Do! Castle Hardware</platform>")
	[void]$builder.AppendLine("	<series>Mr. Do</series>")
	[void]$builder.AppendLine("	<year>$($meta.year)</year>")
	[void]$builder.AppendLine("	<manufacturer>Universal</manufacturer>")
	[void]$builder.AppendLine("	<category>$($meta.category)</category>")
	[void]$builder.AppendLine("	<setname>$($game.set)</setname>")
	[void]$builder.AppendLine("	<parent>$($meta.parent)</parent>")
	[void]$builder.AppendLine("	<mameversion>0288</mameversion>")
	[void]$builder.AppendLine("	<rbf>Arcade-DoCastle</rbf>")
	[void]$builder.AppendLine('	<about author="aCORES" source="MAME universal/docastle.cpp, Universal manuals and PCB evidence" />')
	[void]$builder.AppendLine("	<resolution>15kHz</resolution>")
	[void]$builder.AppendLine("	<rotation>$($game.rotation)</rotation>")
	[void]$builder.AppendLine("	<flip>yes</flip>")
	[void]$builder.AppendLine("	<players>2</players>")
	[void]$builder.AppendLine(("	<joystick>{0}</joystick>" -f $(if ($isSoccer) { "8-way dual" } else { "4-way" })))
	[void]$builder.AppendLine("	<num_buttons>$($controls.count)</num_buttons>")
	[void]$builder.AppendLine(('	<buttons names="{0}" default="{1}" />' -f (Escape-Xml $buttonNames),(Escape-Xml $controls.defaults)))
	[void]$builder.AppendLine()
	[void]$builder.AppendLine(('	<switches default="{0},{1}">' -f $game.dsw1,$game.dsw2))
	foreach ($dipLine in (Get-DipLines $game.set)) {
		[void]$builder.AppendLine($dipLine)
	}
	[void]$builder.AppendLine("	</switches>")
	[void]$builder.AppendLine()
	[void]$builder.AppendLine(('	<rom index="0" zip="{0}" md5="{1}">' -f $game.zip,$md5))

	$cursor = 0
	foreach ($part in ($game.parts | Sort-Object streamOffset)) {
		$gap = [int]$part.streamOffset - $cursor
		if ($gap -lt 0) {
			throw "$($game.set) ROM manifest overlaps before $($part.name)"
		}
		if ($gap -gt 0) {
			[void]$builder.AppendLine(('		<part repeat="{0}">00</part>' -f $gap))
		}
		[void]$builder.AppendLine(('		<part name="{0}" crc="{1}"/>' -f (Escape-Xml $part.name),$part.crc32))
		$cursor = [int]$part.streamOffset + [int]$part.length
	}
	$tail = [int]$definition.imageSize - $cursor
	if ($tail -lt 0) { throw "$($game.set) exceeds the fixed image" }
	if ($tail -gt 0) {
		[void]$builder.AppendLine(('		<part repeat="{0}">00</part>' -f $tail))
	}
	[void]$builder.AppendLine("	</rom>")
	[void]$builder.AppendLine(('	<rom index="1"><part>{0:X2}</part></rom>' -f [int]$game.id))
	[void]$builder.AppendLine("</misterromdescription>")

	$fileName = ($game.name -replace '[<>:"/\\|?*]', '_') + ".mra"
	$outPath = Join-Path $OutputDirectory $fileName
	[IO.File]::WriteAllText($outPath, $builder.ToString())
	Write-Host "Wrote $outPath"
}
