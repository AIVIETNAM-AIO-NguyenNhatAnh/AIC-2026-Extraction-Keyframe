# extract_parallel.ps1 - Ban Windows cua extract_parallel.sh: chay extract_keyframes.py song
# song nhieu video cung luc (thay vi tuan tu tung video) de tan dung nhieu core CPU tren may -
# giam dang ke thoi gian cho so voi chay "python extract_keyframes.py" 1 lan duy nhat (ban do
# xu ly tuan tu toan bo data\raw\).
#
# Dung: .\extract_parallel.ps1          (tu chon so luong song song = so core may - 1)
#       .\extract_parallel.ps1 4        (ep chay dung 4 video cung luc)

param(
  [int]$Jobs = 0
)

$ErrorActionPreference = "Stop"
$ScriptDir = $PSScriptRoot
. (Join-Path $ScriptDir "_common.ps1")

$PythonExe = Find-Python
if (-not $PythonExe) {
  Write-Host "[extract_parallel.ps1] Khong tim thay Python nao tren may." -ForegroundColor Red
  exit 1
}

Ensure-Module -PythonExe $PythonExe -Module "cv2" -PipPackage @("opencv-python")
Ensure-Module -PythonExe $PythonExe -Module "yaml" -PipPackage @("pyyaml")
Ensure-Module -PythonExe $PythonExe -Module "tqdm" -PipPackage @("tqdm")
Ensure-Module -PythonExe $PythonExe -Module "numpy" -PipPackage @("numpy")
# BAT BUOC (khong con tuy chon) - extract_keyframes.py chi con 1 method "transnetv2_similarity",
# khong con fallback nao khac. Thieu goi nay -> moi video se LOI (xem README.md).
Ensure-Module -PythonExe $PythonExe -Module "transnetv2_pytorch" -PipPackage @("transnetv2-pytorch", "ffmpeg-python")

if (-not (Test-FfmpegBinary)) { exit 1 }

Write-Host "[extract_parallel.ps1] Dung interpreter: $PythonExe"

$RawDir = Join-Path $ScriptDir "data\raw"
$videos = Get-VideoFiles -Path $RawDir
if ($videos.Count -eq 0) {
  Write-Host "[extract_parallel.ps1] $RawDir trong - chay '.\download_videos.ps1 memberN' truoc." -ForegroundColor Red
  exit 1
}

# So luong song song: tham so dong lenh neu co (>0), khong thi tu lay so core logic cua may
# tru 1 (may van dung duoc viec khac trong luc chay nen), toi thieu 1.
if ($Jobs -le 0) {
  $cpuCount = [Environment]::ProcessorCount
  $Jobs = if ($cpuCount -gt 1) { $cpuCount - 1 } else { 1 }
}

Write-Host "[extract_parallel.ps1] $($videos.Count) video, chay song song $Jobs luong..."

# Xoa log loi cu truoc khi bat dau luot chay moi - extract_keyframes.py ghi APPEND vao file
# nay (vi nhieu tien trinh song song ben duoi cung ghi vao 1 file), nen phai xoa sach o day
# de khong lan loi cua lan chay truoc.
$failLog = Join-Path $ScriptDir "data\keyframes\_failed_videos.txt"
Remove-Item -Force $failLog -ErrorAction SilentlyContinue

$configPath = Join-Path $ScriptDir "config.yaml"
$scriptPath = Join-Path $ScriptDir "extract_keyframes.py"

$jobsRunning = @()
foreach ($video in $videos) {
  while ($jobsRunning.Count -ge $Jobs) {
    Start-Sleep -Milliseconds 500
    $jobsRunning = @($jobsRunning | Where-Object { $_.Refresh(); -not $_.HasExited })
  }
  $argList = @("`"$scriptPath`"", "--video", "`"$($video.FullName)`"", "--config", "`"$configPath`"")
  $p = Start-Process -FilePath $PythonExe -ArgumentList $argList -NoNewWindow -PassThru
  $jobsRunning += $p
}

foreach ($p in $jobsRunning) { $p.WaitForExit() }

Write-Host ""
Write-Host "[extract_parallel.ps1] Hoan tat. Kiem tra: (Get-ChildItem data\keyframes -Directory).Count"
if (Test-Path $failLog) {
  Write-Host "[extract_parallel.ps1] !!! CANH BAO !!! Co video LOI, xem chi tiet: Get-Content `"$failLog`"" -ForegroundColor Red
}
