param(
    [string]$GodotExe = '',
    [switch]$Native,
    [int]$Port = 24667,
    [string]$Scene = 'tests/LanCoopTests.tscn',
    [int]$RosterBatch = 0,
    # Whole-scenario limit. A healthy 3-peer run takes about 15-25 s; under concurrent load (other Godot
    # instances) a guest can need far longer, and the old fixed 45 s cut it off with no logs.
    [int]$TimeoutSec = 120
)
$gameProject = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
# Default engine: the bundled console exe (stdout reaches the logs), else the standalone 4.7.2 editor exe.
if (-not $GodotExe) {
    $bundledExe = Join-Path $PSScriptRoot '..\tools\steam\engine\Godot_v4.7.2-stable_win64_console.exe'
    if (Test-Path -LiteralPath $bundledExe) { $GodotExe = (Resolve-Path -LiteralPath $bundledExe).Path } else { $GodotExe = 'K:\Godot_v4.7.2-stable_win64.exe' }
}
$testProcesses = @()
$roles = @('host','client1','client2')
# Engine-side ENet noise at shutdown: when a guest quits, the host relays the peer removal to a guest that has
# already disconnected (no GDScript frame on the stack). It is not a test failure; exit codes still are.
$shutdownNoise = @('Unable to send packet on channel 0, max channels: 0', 'at: send (modules/enet/enet_packet_peer.cpp')
# Prints each role's log and error log (minus the shutdown noise); sets $script:roleErrors when any error remains.
$script:roleErrors = $false
function Write-RoleLogs([string[]]$roleList) {
    foreach ($role in $roleList) {
        $log = Join-Path $PSScriptRoot ("lan-final-$role.log")
        $errLog = Join-Path $PSScriptRoot ("lan-final-$role-errors.log")
        if (Test-Path -LiteralPath $log) { Get-Content -LiteralPath $log }
        if (Test-Path -LiteralPath $errLog) {
            $errors = @(Get-Content -LiteralPath $errLog)
            $kept = @($errors | Where-Object { $line = $_; -not ($shutdownNoise | Where-Object { $line.Contains($_) }) })
            if ($errors.Count -ne $kept.Count) { Write-Output ("{0}: ignored {1} ENet shutdown noise line(s)" -f $role, ($errors.Count - $kept.Count)) }
            if ($kept) { $kept; $script:roleErrors = $true }
        }
    }
}
try {
    foreach ($role in $roles) {
        $testArguments = @('--path', ('"' + $gameProject + '"'), $Scene, '--', $role, '--no-steam', '--test-lan-port', "$Port", '--roster-batch', "$RosterBatch")
        if (-not $Native) { $testArguments = @('--headless') + $testArguments }
        $testProcesses += Start-Process -FilePath $GodotExe -ArgumentList $testArguments -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $PSScriptRoot ("lan-final-$role.log")) -RedirectStandardError (Join-Path $PSScriptRoot ("lan-final-$role-errors.log"))
    }
    # Retain native handles so PowerShell can read exit codes after fast exits.
    foreach ($process in $testProcesses) { $null = $process.Handle }
    $started = Get-Date
    try {
        Wait-Process -Id $testProcesses.Id -Timeout $TimeoutSec -ErrorAction Stop
    } catch {
        $late = @()
        for ($i = 0; $i -lt $testProcesses.Count; $i++) {
            if (-not $testProcesses[$i].HasExited) { $late += $roles[$i]; Stop-Process -Id $testProcesses[$i].Id -Force -ErrorAction SilentlyContinue }
        }
        Write-Output ("TIMEOUT after {0:N0} s; still running: {1}" -f ((Get-Date) - $started).TotalSeconds, ($late -join ', '))
        Start-Sleep -Milliseconds 500
        Write-RoleLogs $roles
        exit 1
    }
    Write-Output ("LAN run finished in {0:N1} s" -f ((Get-Date) - $started).TotalSeconds)
    $failed = $false
    foreach ($process in $testProcesses) {
        $process.WaitForExit()
        $process.Refresh()
        if ($process.ExitCode -ne 0) { Write-Output ("Process {0} exit code: {1}" -f $process.Id, $process.ExitCode); $failed = $true }
    }
    Write-RoleLogs $roles
    if ($script:roleErrors) { $failed = $true }
    if ($failed) { exit 1 }
    exit 0
} catch {
    foreach ($process in $testProcesses) {
        if (-not $process.HasExited) { Stop-Process -Id $process.Id }
    }
    throw
}
