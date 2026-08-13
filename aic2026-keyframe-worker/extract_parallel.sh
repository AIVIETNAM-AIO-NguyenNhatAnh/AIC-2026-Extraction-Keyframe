#!/usr/bin/env bash
# Chạy extract_keyframes.py song song nhiều video cùng lúc (thay vì tuần tự từng video) để tận
# dụng nhiều core CPU trên máy — giảm đáng kể thời gian chờ so với chạy "python extract_keyframes.py"
# 1 lần duy nhất (bản đó xử lý tuần tự toàn bộ data/raw/).
#
# Dùng: bash extract_parallel.sh          (tự chọn số luồng song song = số core máy)
#       bash extract_parallel.sh 4        (ép chạy đúng 4 video cùng lúc)
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$DIR/_common.sh"

PYTHON="$(find_python)" || { echo "[extract_parallel.sh] Không tìm thấy Python3 nào trên máy." >&2; exit 1; }
ensure_module "$PYTHON" cv2 opencv-python
ensure_module "$PYTHON" yaml pyyaml
ensure_module "$PYTHON" tqdm tqdm
ensure_module "$PYTHON" numpy numpy
ensure_module "$PYTHON" transnetv2_pytorch transnetv2-pytorch ffmpeg-python
check_ffmpeg_binary

echo "[extract_parallel.sh] Dùng interpreter: $PYTHON -> $($PYTHON -c 'import sys; print(sys.executable)')"

RAW_DIR="$DIR/data/raw"
if [ ! -d "$RAW_DIR" ] || [ -z "$(ls -A "$RAW_DIR" 2>/dev/null)" ]; then
  echo "[extract_parallel.sh] $RAW_DIR trống — chạy 'bash download_videos.sh memberN' trước." >&2
  exit 1
fi

# Số luồng song song: tham số dòng lệnh nếu có, không thì tự lấy số core máy (macOS: sysctl,
# Linux: nproc) — trừ 1 core để máy vẫn dùng được việc khác trong lúc chạy nền.
if [ "${1:-}" != "" ]; then
  JOBS="$1"
elif command -v sysctl >/dev/null 2>&1; then
  JOBS=$(( $(sysctl -n hw.ncpu) > 1 ? $(sysctl -n hw.ncpu) - 1 : 1 ))
elif command -v nproc >/dev/null 2>&1; then
  JOBS=$(( $(nproc) > 1 ? $(nproc) - 1 : 1 ))
else
  JOBS=2
fi

n_videos=$(find "$RAW_DIR" -maxdepth 1 -type f \( -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.mov" -o -iname "*.avi" -o -iname "*.webm" \) | wc -l | tr -d ' ')
echo "[extract_parallel.sh] $n_videos video, chạy song song $JOBS luồng..."

find "$RAW_DIR" -maxdepth 1 -type f \( -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.mov" -o -iname "*.avi" -o -iname "*.webm" \) -print0 \
  | xargs -0 -n 1 -P "$JOBS" -I {} "$PYTHON" "$DIR/extract_keyframes.py" --video {} --config "$DIR/config.yaml"

echo ""
echo "[extract_parallel.sh] Hoàn tất. Kiểm tra: ls data/keyframes/ | wc -l"
