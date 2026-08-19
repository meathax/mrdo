param(
	[int]$WaitForProcessId = 0
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$quartus = "D:\Q\quartus\bin64\quartus_sh.exe"
$log = Join-Path $projectRoot "output_files\Universal_DoCastle.queued-build.log"

function Write-QueueLog([string]$Message) {
	Add-Content -LiteralPath $log -Value ("{0:yyyy-MM-dd HH:mm:ss} {1}" -f (Get-Date),$Message)
}

Write-QueueLog "Queued rebuild waiting for Quartus PID $WaitForProcessId"
if ($WaitForProcessId -gt 0) {
	Wait-Process -Id $WaitForProcessId -ErrorAction SilentlyContinue
}

while (Get-Process -Name quartus_sh,quartus_fit,quartus_map,quartus_asm,quartus_sta -ErrorAction SilentlyContinue) {
	Start-Sleep -Seconds 5
}

Write-QueueLog "Starting Universal_DoCastle Fast Fit rebuild"
Push-Location $projectRoot
try {
	& $quartus --flow compile Universal_DoCastle *>> $log
	$exitCode = $LASTEXITCODE
}
finally {
	Pop-Location
}
Write-QueueLog "Quartus exited with code $exitCode"
exit $exitCode
