#!/usr/bin/env bash
# Dùng chung cho run.sh và run_web.sh: tìm ĐÚNG 1 Python interpreter và luôn cài thiếu gì
# thì bù vào đúng interpreter đó — không bao giờ trộn giữa 2 bản Python khác nhau nữa
# (nguyên nhân toàn bộ lỗi "pip nói đã cài" nhưng "ModuleNotFoundError" trước đây).

PY_CANDIDATES=(
  python3.13 python3.12 python3.11 python3.10 python3.9
  /usr/local/bin/python3.13 /usr/local/bin/python3.12 /usr/local/bin/python3.11 /usr/local/bin/python3.10 /usr/local/bin/python3
  /opt/homebrew/bin/python3.13 /opt/homebrew/bin/python3.12 /opt/homebrew/bin/python3.11 /opt/homebrew/bin/python3.10 /opt/homebrew/bin/python3
  python3 python
)

# find_python: in ra đường dẫn 1 interpreter có sẵn cv2+numpy nếu có; nếu không bản nào có,
# lấy bản python3 đầu tiên tìm thấy và cài opencv-python+numpy (2 gói nhẹ, luôn cài được)
# vào đúng bản đó rồi trả về bản đó luôn — KHÔNG bao giờ cài vào 1 bản rồi chạy bằng bản khác.
find_python() {
  local c
  for c in "${PY_CANDIDATES[@]}"; do
    if command -v "$c" >/dev/null 2>&1 && "$c" -c "import cv2, numpy" >/dev/null 2>&1; then
      echo "$c"
      return 0
    fi
  done
  for c in "${PY_CANDIDATES[@]}"; do
    if command -v "$c" >/dev/null 2>&1; then
      echo "[_common.sh] Cài opencv-python + numpy vào $c ..." >&2
      "$c" -m pip install --user opencv-python numpy >&2
      echo "$c"
      return 0
    fi
  done
  return 1
}

# ensure_module PYTHON module pip_package...: cài thêm 1 gói vào ĐÚNG interpreter đang dùng
# nếu module đó chưa import được — không tự đổi sang interpreter khác.
ensure_module() {
  local py="$1" mod="$2"; shift 2
  if ! "$py" -c "import $mod" >/dev/null 2>&1; then
    echo "[_common.sh] Cài thêm $* vào $py ..." >&2
    "$py" -m pip install --user "$@" >&2
  fi
}

# ensure_optional PYTHON module pip_package...: giống ensure_module nhưng không dừng script
# nếu cài lỗi. KHÔNG dùng cho transnetv2-pytorch/ffmpeg-python nữa (extract_keyframes.py chỉ
# còn 1 method, không còn fallback nào để chạy tiếp nếu thiếu — xem ensure_module ở
# extract_parallel.sh). Giữ lại hàm này cho dependency thật sự tuỳ chọn nếu cần sau này.
ensure_optional() {
  local py="$1" mod="$2"; shift 2
  if ! "$py" -c "import $mod" >/dev/null 2>&1; then
    echo "[_common.sh] (tuỳ chọn) Cài thêm $* vào $py — nếu lỗi vẫn chạy tiếp được..." >&2
    "$py" -m pip install --user "$@" >&2 || true
  fi
}

check_ffmpeg_binary() {
  if ! command -v ffmpeg >/dev/null 2>&1; then
    echo "[_common.sh] !!! CẢNH BÁO !!! Chưa thấy lệnh 'ffmpeg' trên máy. Cách 5 (TransNetV2) —" >&2
    echo "  method DUY NHẤT để trích keyframe — BẮT BUỘC cần ffmpeg để đọc video. Thiếu ffmpeg" >&2
    echo "  thì extract_keyframes.py sẽ LỖI cho mọi video (không còn method dự phòng nào khác)." >&2
    echo "  Cài ngay: brew install ffmpeg (macOS) / apt install -y ffmpeg (Linux) rồi chạy lại." >&2
  fi
}
