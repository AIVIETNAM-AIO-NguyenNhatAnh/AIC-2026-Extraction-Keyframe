# package_results.ps1 - Ban Windows cua package_results.sh: nen toan bo data\keyframes\ (anh +
# frame_index.json da trich) thanh 1 file zip de gui lai cho truong nhom - KHONG nen data\raw\
# (video goc, qua nang, khong can gui lai vi ai cung tai duoc tu nguon chung).
#
# Dung: .\package_results.ps1 member1   (ten file zip se co "member1" + ngay gio)

param(
  [string]$Label = "ketqua"
)

$ErrorActionPreference = "Stop"
$ScriptDir = $PSScriptRoot
$KeyframesDir = Join-Path $ScriptDir "data\keyframes"
$Stamp = Get-Date -Format "yyyyMMdd_HHmm"
$Out = Join-Path $ScriptDir "keyframes_${Label}_${Stamp}.zip"

if (-not (Test-Path $KeyframesDir) -or (Get-ChildItem $KeyframesDir -ErrorAction SilentlyContinue).Count -eq 0) {
  Write-Host "[package_results.ps1] data\keyframes\ dang trong - chay extract_parallel.ps1 (hoac extract_keyframes.py) truoc." -ForegroundColor Red
  exit 1
}

# Dung thu muc tam de giu DUNG cau truc "data\keyframes\..." ben trong file zip (giong het ban
# zip tao boi package_results.sh tren Mac/Linux) - de lenh gop ket qua cua truong nhom trong
# README.md dung chung cho ca 2 he dieu hanh, khong can phan biet.
$stageRoot = Join-Path $env:TEMP ("aic_kf_pkg_" + [guid]::NewGuid().ToString("N"))
$stageTarget = Join-Path $stageRoot "data\keyframes"
New-Item -ItemType Directory -Force -Path $stageTarget | Out-Null
Copy-Item -Path (Join-Path $KeyframesDir "*") -Destination $stageTarget -Recurse -Force

try {
  Compress-Archive -Path (Join-Path $stageRoot "data") -DestinationPath $Out -Force
} finally {
  Remove-Item -Recurse -Force $stageRoot -ErrorAction SilentlyContinue
}

$nDirs = (Get-ChildItem $KeyframesDir -Directory -ErrorAction SilentlyContinue).Count
Write-Host "[package_results.ps1] Da dong goi $nDirs video -> $Out"
Write-Host "[package_results.ps1] Gui file nay (qua Zalo/Google Drive/email) cho truong nhom."

$failLog = Join-Path $KeyframesDir "_failed_videos.txt"
if (Test-Path $failLog) {
  Write-Host "[package_results.ps1] !!! CANH BAO !!! Van con video LOI (data\keyframes\_failed_videos.txt) -" -ForegroundColor Red
  Write-Host "  sua dependency roi chay lai dung video do TRUOC KHI gui, keo thieu keyframe." -ForegroundColor Red
}
