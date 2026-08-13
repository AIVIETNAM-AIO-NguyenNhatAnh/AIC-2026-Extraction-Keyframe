#!/usr/bin/env bash
# Chạy trọn gói cho 1 thành viên: tải video được giao -> trích keyframe song song -> đóng gói
# kết quả thành zip để gửi lại. Chỉ cần 1 lệnh duy nhất.
#
# Dùng: bash run_all.sh member1   (member1..member5 — xem phân công trong README.md)
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$DIR"

MEMBER="${1:-}"
if [ -z "$MEMBER" ]; then
  echo "Dùng: bash run_all.sh memberN   (N = 1..5, đúng phần bạn được giao — xem README.md)" >&2
  exit 1
fi

echo "======================================================================"
echo " Bước 1/3 — Tải video được giao ($MEMBER)"
echo "======================================================================"
bash download_videos.sh "$MEMBER"

echo ""
echo "======================================================================"
echo " Bước 2/3 — Trích keyframe (chạy song song nhiều video cùng lúc)"
echo "======================================================================"
bash extract_parallel.sh

echo ""
echo "======================================================================"
echo " Bước 3/3 — Đóng gói kết quả"
echo "======================================================================"
bash package_results.sh "$MEMBER"

echo ""
echo "Xong! Gửi file zip vừa tạo (keyframes_${MEMBER}_*.zip) cho trưởng nhóm."
