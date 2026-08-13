#!/usr/bin/env bash
# Nén toàn bộ data/keyframes/ (ảnh + frame_index.json đã trích) thành 1 file zip để gửi lại cho
# trưởng nhóm — KHÔNG nén data/raw/ (video gốc, quá nặng, không cần gửi lại vì ai cũng tải được
# từ nguồn chung).
#
# Dùng: bash package_results.sh member1   (tên file zip sẽ có "member1" + ngày giờ)
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LABEL="${1:-ketqua}"
STAMP="$(date +%Y%m%d_%H%M)"
OUT="$DIR/keyframes_${LABEL}_${STAMP}.zip"

if [ ! -d "$DIR/data/keyframes" ] || [ -z "$(ls -A "$DIR/data/keyframes" 2>/dev/null)" ]; then
  echo "[package_results.sh] data/keyframes/ đang trống — chạy extract_parallel.sh (hoặc extract_keyframes.py) trước." >&2
  exit 1
fi

cd "$DIR"
zip -r -q "$OUT" data/keyframes

n_dirs=$(find data/keyframes -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')
echo "[package_results.sh] Đã đóng gói $n_dirs video -> $OUT"
echo "[package_results.sh] Gửi file này (qua Zalo/Google Drive/email) cho trưởng nhóm."
