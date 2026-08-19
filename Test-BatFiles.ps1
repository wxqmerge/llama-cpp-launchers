param(
    [string]$Folder = 'D:\llama.cpp.b10472',
    [int]$TimeoutSeconds = 10
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$originalDir = Get-Location
try {
    Set-Location $Folder
    $bats = Get-ChildItem -Path $Folder -Filter '*.bat' | Where-Object { $_.Name -ne 'stop.bat' }

    $results = @()
    foreach ($bat in $bats) {
        $name = $bat.Name
        Write-Host "Stopping any running llama-server..."
        Get-Process llama-server -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        Write-Host "Testing $name ..." 
        $started = $null
        try {
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = 'cmd.exe'
            $psi.Arguments = "/c `"$($bat.FullName)`""
            $psi.UseShellExecute = $false
            $psi.RedirectStandardOutput = $true
            $psi.RedirectStandardError = $true
            $psi.CreateNoWindow = $true
            $proc = New-Object System.Diagnostics.Process
            $proc.StartInfo = $psi
            $proc.Start() | Out-Null
            $started = $proc
            $timedOut = $false
            if (-not $proc.WaitForExit($TimeoutSeconds * 1000)) {
                $timedOut = $true
                try { $proc.Kill() } catch {}
                # try to kill any llama-server spawned
                Get-Process llama-server -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
            }
            $out = $proc.StandardOutput.ReadToEnd()
            $err = $proc.StandardError.ReadToEnd()
            $exit = $proc.ExitCode
            $status = if ($timedOut) { 'TimedOut' } elseif ($exit -eq 0) { 'OK' } else { 'Error' }
        } catch {
            $status = 'Exception'
            $err = $_.Exception.Message
        } finally {
            if ($started -and -not $started.HasExited) {
                try { $started.Kill() } catch {}
            }
        }
        $results += [pscustomobject]@{
            File = $name
            Status = $status
            ExitCode = $exit
            StdErr = $err
        }
        Write-Host "  -> $status"
    }

    Write-Host "`nSummary:"
    $results | Format-Table -AutoSize
    $results | Export-Csv -Path (Join-Path $Folder 'bat_test_results.csv') -NoTypeInformation
    Write-Host "Results saved to bat_test_results.csv"
}
finally {
    Set-Location $originalDir
}
