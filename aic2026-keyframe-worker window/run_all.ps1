# run_all.ps1 - Ban Windows cua run_all.sh: chay tron goi cho 1 thanh vien - tai video duoc
# giao -> trich keyframe song song -> dong goi ket qua thanh zip de gui lai. Chi can 1 lenh.
#
# Dung: .\run_all.ps1 member1   (member1..member5 - xem phan cong trong README.md)

param(
  [string]$Member
)

$ErrorActionPreference = "Stop"
$ScriptDir = $PSScriptRoot
Set-Location $ScriptDir

if (-not $Member) {
  Write-Host "Dung: .\run_all.ps1 memberN   (N = 1..5, dung phan ban duoc giao - xem README.md)" -ForegroundColor Red
  exit 1
}

Write-Host "======================================================================"
Write-Host " Buoc 1/3 - Tai video duoc giao ($Member)"
Write-Host "======================================================================"
& (Join-Path $ScriptDir "download_videos.ps1") $Member
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "======================================================================"
Write-Host " Buoc 2/3 - Trich keyframe (chay song song nhieu video cung luc)"
Write-Host "======================================================================"
& (Join-Path $ScriptDir "extract_parallel.ps1")
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "======================================================================"
Write-Host " Buoc 3/3 - Dong goi ket qua"
Write-Host "======================================================================"
& (Join-Path $ScriptDir "package_results.ps1") $Member
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host ""
Write-Host "Xong! Gui file zip vua tao (keyframes_${Member}_*.zip) cho truong nhom."
