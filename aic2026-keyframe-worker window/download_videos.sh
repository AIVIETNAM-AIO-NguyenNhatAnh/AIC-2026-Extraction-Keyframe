#!/usr/bin/env bash
# Tải ĐÚNG PHẦN video được giao cho 1 thành viên trong team (14 file Videos_*.zip của batch 1
# AIC 2026 đã được chia sẵn cho 5 người bên dưới — xem README.md mục "Phân công"), giải nén,
# gom video ra data/raw/, xoá zip ngay sau khi giải nén (đỡ tốn dung lượng đĩa).
#
# Dùng: bash download_videos.sh member1   (member1..member5)
# Muốn tải danh sách khác (vd. giúp đỡ người khác, hoặc tự chia lại), truyền thẳng tên file:
#   bash download_videos.sh Videos_L21_a.zip Videos_L22_a.zip

set -euo pipefail

BASE_URL="https://aic-data.ledo.io.vn"
RAW_DIR="data/raw"
TMP_DIR="$(mktemp -d)"

# Phân công 14 file cho 5 thành viên — chia đều nhất có thể (3/3/3/3/2). Đổi lại ở đây nếu
# team muốn chia khác, rồi gửi lại bản config này cho mọi người dùng chung 1 bản duy nhất.
member1=(Videos_L21_a.zip Videos_L22_a.zip Videos_L23_a.zip)
member2=(Videos_L24_a.zip Videos_L25_a.zip Videos_L26_a.zip)
member3=(Videos_L26_b.zip Videos_L26_c.zip Videos_L26_d.zip)
member4=(Videos_L26_e.zip Videos_L27_a.zip Videos_L28_a.zip)
member5=(Videos_L29_a.zip Videos_L30_a.zip)

case "${1:-}" in
  member1) FILES=("${member1[@]}") ;;
  member2) FILES=("${member2[@]}") ;;
  member3) FILES=("${member3[@]}") ;;
  member4) FILES=("${member4[@]}") ;;
  member5) FILES=("${member5[@]}") ;;
  "")
    echo "Dùng: bash download_videos.sh member1   (hoặc member2..member5, hoặc liệt kê tên file zip cụ thể)" >&2
    exit 1
    ;;
  *) FILES=("$@") ;;
esac

echo ">>> Sẽ tải ${#FILES[@]} file: ${FILES[*]}"

command -v aria2c >/dev/null 2>&1 || {
  echo "Lỗi: cần lệnh 'aria2c' (tải đa luồng, server nguồn giới hạn tốc độ mỗi kết nối rất thấp)." >&2
  echo "Cài bằng: brew install aria2   (macOS)   hoặc   apt install -y aria2   (Linux)" >&2
  exit 1
}

mkdir -p "$RAW_DIR"
trap 'rm -rf "$TMP_DIR"' EXIT

for fname in "${FILES[@]}"; do
  echo ">>> Tải $fname ..."
  aria2c -x 16 -s 16 -k 1M --retry-wait=3 --max-tries=5 \
    -d "$TMP_DIR" -o "$fname" "$BASE_URL/$fname"

  echo ">>> Giải nén $fname ..."
  unzip -q -o "$TMP_DIR/$fname" -d "$TMP_DIR/extract"

  find "$TMP_DIR/extract" -type f \( -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.mov" -o -iname "*.avi" -o -iname "*.webm" \) \
    -exec mv -n {} "$RAW_DIR/" \;

  rm -rf "$TMP_DIR/extract" "$TMP_DIR/$fname"
  echo ">>> Xong $fname"
done

n_videos=$(find "$RAW_DIR" -maxdepth 1 -type f \( -iname "*.mp4" -o -iname "*.mkv" -o -iname "*.mov" -o -iname "*.avi" -o -iname "*.webm" \) | wc -l)
echo ""
echo "Hoàn tất. $n_videos video đang có trong $RAW_DIR/."
