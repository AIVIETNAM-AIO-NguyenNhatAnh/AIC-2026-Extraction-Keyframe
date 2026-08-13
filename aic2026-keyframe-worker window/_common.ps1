# _common.ps1 - Ban Windows (PowerShell) cua _common.sh: tim 1 Python interpreter va tu cai cac
# goi con thieu vao dung interpreter do - khong bao gio tron 2 ban Python khac nhau (nguyen nhan
# loi kieu "pip noi da cai" nhung "ModuleNotFoundError" tren Mac/Linux truoc day).
# Dung: . .\_common.ps1   (dau cham + dau cach + duong dan - "dot-source", KHONG chay truc tiep)

$script:PyCandidates = @(
  @{ Cmd = "py";         PreArgs = @("-3.13") },
  @{ Cmd = "py";         PreArgs = @("-3.12") },
  @{ Cmd = "py";         PreArgs = @("-3.11") },
  @{ Cmd = "py";         PreArgs = @("-3.10") },
  @{ Cmd = "py";         PreArgs = @("-3.9") },
  @{ Cmd = "python3.13"; PreArgs = @() },
  @{ Cmd = "python3.12"; PreArgs = @() },
  @{ Cmd = "python3.11"; PreArgs = @() },
  @{ Cmd = "python3.10"; PreArgs = @() },
  @{ Cmd = "python3.9";  PreArgs = @() },
  @{ Cmd = "python";     PreArgs = @() },
  @{ Cmd = "python3";    PreArgs = @() }
)

function Resolve-PythonExe {
  # Tra ve duong dan python.exe THAT (sys.executable) cho 1 candidate, hoac $null neu khong
  # chay duoc (lenh khong ton tai tren may). Ho tro ca "py -3.11" (Python Launcher, cach cai
  # pho bien nhat tren Windows) lan "python3.11"/"python" (neu co trong PATH).
  param($Candidate)
  $cmd = Get-Command $Candidate.Cmd -ErrorAction SilentlyContinue
  if (-not $cmd) { return $null }
  try {
    $allArgs = $Candidate.PreArgs + @("-c", "import sys; print(sys.executable)")
    $exe = & $Candidate.Cmd @allArgs 2>$null
    if ($LASTEXITCODE -eq 0 -and $exe) { return ($exe | Select-Object -First 1).Trim() }
  } catch {}
  return $null
}

function Find-Python {
  # In ra duong dan 1 interpreter co san cv2+numpy neu co; neu khong ban nao co, lay ban dau
  # tien tim thay va cai opencv-python+numpy (2 goi nhe, luon cai duoc) vao dung ban do roi tra
  # ve ban do luon - KHONG bao gio cai vao 1 ban roi chay bang ban khac.
  foreach ($c in $script:PyCandidates) {
    $exe = Resolve-PythonExe $c
    if ($exe) {
      & $exe -c "import cv2, numpy" 2>$null | Out-Null
      if ($LASTEXITCODE -eq 0) { return $exe }
    }
  }
  foreach ($c in $script:PyCandidates) {
    $exe = Resolve-PythonExe $c
    if ($exe) {
      Write-Host "[_common.ps1] Cai opencv-python + numpy vao $exe ..." -ForegroundColor Yellow
      & $exe -m pip install --user opencv-python numpy
      return $exe
    }
  }
  return $null
}

function Ensure-Module {
  # Cai them 1 goi vao DUNG interpreter dang dung neu module do chua import duoc.
  param(
    [Parameter(Mandatory = $true)][string]$PythonExe,
    [Parameter(Mandatory = $true)][string]$Module,
    [Parameter(Mandatory = $true)][string[]]$PipPackage
  )
  & $PythonExe -c "import $Module" 2>$null | Out-Null
  if ($LASTEXITCODE -ne 0) {
    Write-Host "[_common.ps1] Cai them $($PipPackage -join ' ') vao $PythonExe ..." -ForegroundColor Yellow
    & $PythonExe -m pip install --user @PipPackage
  }
}

function Test-FfmpegBinary {
  # BAT BUOC - extract_keyframes.py chi con 1 method "transnetv2_similarity" (Cach 5), khong
  # con method du phong nao khac. Thieu ffmpeg thi TransNetV2 khong doc duoc video -> video do
  # se LOI hoan toan (khong con tu roi ve "uniform" nhu truoc).
  if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    Write-Host "[_common.ps1] !!! CANH BAO !!! Chua thay lenh 'ffmpeg' tren may. Cach 5 (TransNetV2)" -ForegroundColor Red
    Write-Host "  - method DUY NHAT de trich keyframe - BAT BUOC can ffmpeg de doc video. Thieu" -ForegroundColor Red
    Write-Host "  ffmpeg thi extract_keyframes.py se LOI cho moi video." -ForegroundColor Red
    Write-Host "  Cai ngay: winget install ffmpeg   (hoac choco install ffmpeg, hoac tai thu cong" -ForegroundColor Red
    Write-Host "  tu ffmpeg.org roi them vao PATH) roi chay lai." -ForegroundColor Red
    return $false
  }
  return $true
}

function Test-Aria2cBinary {
  if (-not (Get-Command aria2c -ErrorAction SilentlyContinue)) {
    Write-Host "[_common.ps1] Loi: can lenh 'aria2c' (tai da luong, server nguon gioi han toc do moi ket noi rat thap)." -ForegroundColor Red
    Write-Host "  Cai bang: winget install aria2.aria2   (hoac choco install aria2, hoac tai thu cong tu github.com/aria2/aria2/releases roi them vao PATH)" -ForegroundColor Red
    return $false
  }
  return $true
}

function Get-VideoFiles {
  # Liet ke file video (.mp4/.mkv/.mov/.avi/.webm) trong 1 thu muc - dung chung cho
  # download_videos.ps1 va extract_parallel.ps1 thay vi Get-ChildItem -Include (de vo tinh bo
  # sot tren mot so phien ban PowerShell khi khong ket hop dung -Recurse/wildcard path).
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [switch]$Recurse
  )
  $exts = @(".mp4", ".mkv", ".mov", ".avi", ".webm")
  if (-not (Test-Path $Path)) { return @() }
  $items = if ($Recurse) { Get-ChildItem -Path $Path -File -Recurse } else { Get-ChildItem -Path $Path -File }
  return $items | Where-Object { $exts -contains $_.Extension.ToLower() }
}
