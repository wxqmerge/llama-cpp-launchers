#Requires -Version 5.1
param(
    [string]$InstallRoot = "D:\",
    [string]$Repo = "ggml-org/llama.cpp",
    [string]$CudaDllZip = "D:\cudart-llama-bin-win-cuda-13.4-x64.zip",
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$allReleases = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/releases?per_page=100"
$apiHeaders = $allReleases | Where-Object { $_.tag_name -match '^b\d+$' } | Select-Object -First 1

if (-not $apiHeaders) {
    Write-Error "Could not find a release with bxxxx tag"
    exit 1
}

$tag = $apiHeaders.tag_name
if ($tag -notmatch 'b\d+') {
    Write-Error "Could not parse build number from tag '$tag'"
    exit 1
}
$buildNum = $Matches[0]
$folderName = "llama.cpp.$buildNum"
$newPath = Join-Path $InstallRoot $folderName

$existing = Get-ChildItem $InstallRoot -Filter "llama.cpp.b*" -Directory |
    Sort-Object { [int]($_.Name -replace '.*b(\d+)', '$1') } -Descending
$prevPath = if ($existing) { $existing[0].FullName } else { $null }

# Main build: llama-b<build>-bin-win-cuda-13.4-x64.zip (code-only; CUDA DLLs added separately from $CudaDllZip)
$asset = $apiHeaders.assets |
    Where-Object { $_.name -match '^llama-b.*bin-win-cuda-13\.4-x64\.zip$' } |
    Select-Object -First 1

if (-not $asset) {
    Write-Error "Could not find Windows x64 CUDA 13.4 build in release $tag"
    exit 1
}

if (-not (Test-Path $CudaDllZip)) {
    Write-Error "CUDA DLL zip not found: $CudaDllZip"
    exit 1
}
$cudaSize = [math]::Round((Get-Item $CudaDllZip).Length / 1MB, 1)

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  llama.cpp Updater" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Release:    $($apiHeaders.tag_name)"
Write-Host "Build:      $($asset.name) ($([math]::Round($asset.size / 1MB, 1)) MB)"
Write-Host "CUDA DLLs:  $([System.IO.Path]::GetFileName($CudaDllZip)) ($cudaSize MB)"
Write-Host "Install to: $newPath"
Write-Host "Prev bats:  $(if ($prevPath) { $prevPath } else { 'None found' })"
Write-Host "----------------------------------------" -ForegroundColor DarkGray

# Check if build already extracted
$needsExtract = $true
if (Test-Path $newPath) {
    $existingExe = Get-ChildItem $newPath -Filter "llama-*" -File | Where-Object { $_.Extension -eq '.exe' }
    if ($existingExe) {
        Write-Host "`n[SKIP] Build already extracted ($($existingExe.Count) exes found). Resuming..." -ForegroundColor Yellow
        $needsExtract = $false
    } elseif ($Force) {
        Write-Host "`n[WARN] $folderName exists but incomplete. Removing..." -ForegroundColor Yellow
        Remove-Item $newPath -Recurse -Force
    } else {
        Write-Host "`n$folderName exists but incomplete. Use -Force to reinstall." -ForegroundColor Yellow
        exit 1
    }
}

if ($needsExtract) {
    # [1/4] Download main build
    $zipPath = Join-Path $env:TEMP "$folderName.zip"
    Write-Host "`n[1/4] Downloading build..." -ForegroundColor Green
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zipPath -UseBasicParsing
    Write-Host "       $([math]::Round((Get-Item $zipPath).Length / 1MB, 1)) MB" -ForegroundColor Gray

    # [2/4] Extract main build
    Write-Host "[2/4] Extracting build..." -ForegroundColor Green
    Expand-Archive -Path $zipPath -DestinationPath $newPath -Force
    Remove-Item $zipPath -Force
    Write-Host "       $newPath" -ForegroundColor Gray
}

# [3/4] Copy CUDA DLLs from local zip
Write-Host "[3/4] Copying CUDA DLLs..." -ForegroundColor Green
$tmpCuda = Join-Path $env:TEMP "cuda-dlls-extract"
if (Test-Path $tmpCuda) { Remove-Item $tmpCuda -Recurse -Force }
New-Item -ItemType Directory -Path $tmpCuda -Force | Out-Null
Expand-Archive -Path $CudaDllZip -DestinationPath $tmpCuda -Force

$cudaDlls = Get-ChildItem $tmpCuda -Filter "*.dll" -File -Recurse
foreach ($dll in $cudaDlls) {
    Copy-Item $dll.FullName $newPath -Force
    Write-Host "       $($dll.Name)" -ForegroundColor Gray
}
Remove-Item $tmpCuda -Recurse -Force
if (-not $cudaDlls) {
    Write-Host "       WARNING: No .dll files found in CUDA zip." -ForegroundColor Yellow
}

# [4/4] Copy .bat files from previous version
if ($prevPath) {
    Write-Host "[4/4] Copying .bat files..." -ForegroundColor Green
    $bats = Get-ChildItem $prevPath -Filter "*.bat" -File -Recurse
    foreach ($bat in $bats) {
        $relPath = $bat.FullName -replace [regex]::Escape("$prevPath\"), ''
        $relDir = [System.IO.Path]::GetDirectoryName($relPath)
        $targetDir = if ($relDir) { Join-Path $newPath $relDir } else { $newPath }
        if (-not (Test-Path $targetDir)) {
            New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
        }
        Copy-Item $bat.FullName (Join-Path $targetDir $bat.Name)
        Write-Host "       $($bat.Name)" -ForegroundColor Gray
    }
    if (-not $bats) {
        Write-Host "       No .bat files found." -ForegroundColor Gray
    }
} else {
    Write-Host "[4/4] No previous version. Skipping .bat copy." -ForegroundColor Gray
}

# Summary
$mainExe = (Get-ChildItem $newPath -Filter "llama-*" -File | Where-Object { $_.Extension -eq '.exe' })[0]
$dllCount = (Get-ChildItem $newPath -Filter "*.dll" -File).Count

Write-Host "`nDone!" -ForegroundColor Green
Write-Host "Exe:       $(if ($mainExe) { $mainExe.Name } else { 'Not found' })" -ForegroundColor Gray
Write-Host "DLLs:      $dllCount" -ForegroundColor Gray
Write-Host "Folder:    $newPath" -ForegroundColor Gray

$binPath = if ($mainExe) { $mainExe.DirectoryName } else { $newPath }
Write-Host "`nAdd to PATH:" -ForegroundColor DarkYellow
Write-Host "  [Environment]::SetEnvironmentVariable('Path', `"$binPath;$([Environment]::GetEnvironmentVariable('Path','Machine'))`", 'Machine')" -ForegroundColor DarkGray