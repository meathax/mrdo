param(
    [string]$Game = "docastle",
    [int]$GameId = 0,
    [int]$Frames = 120,
    [string]$MameExe = $(if ($env:MAME_EXE) { $env:MAME_EXE } else { "D:\Arcade\AI\mame\mame.exe" }),
    [switch]$Detached,
    [switch]$Strict
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $projectRoot
$env:PATH = "C:\msys64\ucrt64\bin;C:\msys64\usr\bin;$env:PATH"
$MameExe = [IO.Path]::GetFullPath($MameExe)
if (-not (Test-Path -LiteralPath $MameExe)) { throw "MAME executable not found: $MameExe" }

& "$PSScriptRoot\build_visual.ps1"
$model = [IO.Path]::GetFullPath((Join-Path $projectRoot "obj_dir_visual\Vdocastle_core.exe"))
$rom = [IO.Path]::GetFullPath((Join-Path $projectRoot "verif\out\$Game.rom"))
if (-not (Test-Path -LiteralPath $rom)) { throw "ROM image not found: $rom" }

$stamp = Get-Date -Format "yyyyMMdd_HHmmss"
$session = [IO.Path]::GetFullPath((Join-Path $projectRoot "verif\lockstep\${Game}_${stamp}"))
New-Item -ItemType Directory -Force -Path $session, (Join-Path $session "rtl"),
    (Join-Path $session "reference"), (Join-Path $session "inputs"),
    (Join-Path $session "diff"), (Join-Path $session "logs") | Out-Null

$env:DOCASTLE_LOCKSTEP_SESSION = $session
$env:DOCASTLE_LOCKSTEP_FRAMES = [string]$Frames
$simLog = Join-Path $session "logs\rtl.log"
$simErrLog = Join-Path $session "logs\rtl.err.log"
$mameLog = Join-Path $session "logs\mame.log"
$mameErrLog = Join-Path $session "logs\mame.err.log"
$coordLog = Join-Path $session "logs\coordinator.log"
$coordErrLog = Join-Path $session "logs\coordinator.err.log"
$verilatorSafe = [IO.Path]::GetFullPath("C:\Users\meath\bin\verilator-safe.exe")
$python = (Get-Command python.exe -ErrorAction Stop).Source

$simArguments = @($model, $rom, $GameId, $session, $Frames)
$mameArguments = @(
    $Game, "-rompath", $projectRoot, "-window", "-skip_gameinfo", "-nothrottle",
    "-video", "gdi", "-sound", "none", "-samplerate", "48000",
    "-cfg_directory", (Join-Path $session "cfg"),
    "-nvram_directory", (Join-Path $session "nvram"),
    "-state_directory", (Join-Path $session "state"),
    "-snapshot_directory", (Join-Path $session "snapshots"),
    "-autoboot_script", [IO.Path]::GetFullPath((Join-Path $PSScriptRoot "mame_lockstep.lua"))
)
foreach ($directory in "cfg", "nvram", "state", "snapshots") {
    New-Item -ItemType Directory -Force -Path (Join-Path $session $directory) | Out-Null
}

$simProcess = $null
$mameProcess = $null
$coordProcess = $null
try {
    # Use the canonical safe wrapper form. It acquires a simulation lane and
    # then launches the visible SDL participant on its pinned P-core.
    $simProcess = Start-Process -FilePath $verilatorSafe -ArgumentList (@("sim") + $simArguments) -WorkingDirectory $projectRoot -RedirectStandardOutput $simLog -RedirectStandardError $simErrLog -PassThru
    $mameProcess = Start-Process -FilePath $MameExe -ArgumentList $mameArguments -WorkingDirectory $projectRoot -RedirectStandardOutput $mameLog -RedirectStandardError $mameErrLog -PassThru
    $coordArgs = @([IO.Path]::GetFullPath((Join-Path $PSScriptRoot "lockstep_coordinator.py")), $session,
        "--frames", $Frames)
    if ($Strict) { $coordArgs += "--strict" }
    if ($Detached) {
        $coordProcess = Start-Process -FilePath $python -ArgumentList $coordArgs -WorkingDirectory $projectRoot -RedirectStandardOutput $coordLog -RedirectStandardError $coordErrLog -PassThru
        Write-Host "STARTED detached lockstep session: $session"
        Write-Host "RTL window and MAME window remain live; comparison log: $coordLog"
        return
    }
    & $python @coordArgs
    $coordExit = $LASTEXITCODE
    if ($coordExit -ne 0) { throw "lockstep coordinator failed with exit code $coordExit" }
    if ($simProcess -and -not $simProcess.HasExited) { $simProcess.WaitForExit() }
    if ($mameProcess -and -not $mameProcess.HasExited) { $mameProcess.WaitForExit() }
    Write-Host "PASS lockstep session: $session"
} finally {
    if (-not $Detached) {
        foreach ($process in @($simProcess, $mameProcess, $coordProcess)) {
            if ($process -and -not $process.HasExited) { Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue }
        }
    }
    Remove-Item Env:DOCASTLE_LOCKSTEP_SESSION -ErrorAction SilentlyContinue
    Remove-Item Env:DOCASTLE_LOCKSTEP_FRAMES -ErrorAction SilentlyContinue
}
