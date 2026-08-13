"""
Trích keyframe từ video — CHỈ 1 method duy nhất: "transnetv2_similarity" (Cách 5, tham khảo
final/report.md + final/extract_keyframes_method5.py của nhóm, đã benchmark: ít frame hơn
uniform sampling/Cách 3 mà vẫn giữ gần như toàn bộ nội dung).

Method "uniform" (lấy đều N giây/frame, không quan tâm nội dung) đã được GỠ BỎ hoàn toàn khỏi
repo — trước đây dùng làm baseline + fallback im lặng khi thiếu transnetv2-pytorch, nhưng gây
hiểu lầm thực tế ("tưởng đã dùng Cách 5 nhưng thực ra âm thầm chạy uniform", ra keyframe cách đều
nhau thay vì theo shot). Giờ nếu thiếu dependency, code RAISE LỖI RÕ RÀNG thay vì tự hạ cấp xuống
uniform — xem _extract_one.

Cách hoạt động: dùng TransNetV2 (pip package `transnetv2-pytorch`, có sẵn weight, không cần tải
riêng) để chia video thành shot; trong mỗi shot, duyệt frame ứng viên (mỗi candidate_every_seconds
giây) và chỉ giữ frame khi đủ khác frame vừa giữ gần nhất (so theo ảnh thu nhỏ 16x16 RGB, L1
distance >= similarity_threshold) -> số frame tự thích nghi theo nội dung, đoạn tĩnh ra ít frame,
đoạn nhiều biến động ra nhiều frame hơn. Đọc frame bằng cv2 tuần tự (một lượt duy nhất, không seek
nhiều lần) nên chính xác đến từng frame gốc, không giới hạn ở lưới sample như bản ffmpeg gốc
trong final/.

Input:  video trong data/raw/
Output: ảnh keyframe (.jpg) trong data/keyframes/{video_id}/frame_{frame_id:06d}.jpg
        + data/keyframes/{video_id}/frame_index.json
          -> [{"frame_id":.., "timestamp":.., "shot_id":.., "path":.., "method":"transnetv2_similarity"}]

QUAN TRỌNG — ý nghĩa frame_id: theo "Thông tin vòng Sơ tuyển AIC2026.pdf" mục 3 ("Keyframe được
lưu trong thư mục... vị trí (frame index) tương ứng của mỗi keyframe được ghi trong file
metadata") và mục 2.1.1 (ví dụ chấm điểm "frame_id = 1500", điều kiện idᵢ ∈ [s, e]), frame_id
PHẢI là VỊ TRÍ FRAME THẬT trong video gốc (đếm từ 0, theo đúng frame rate gốc) — không phải số
thứ tự của keyframe đã lưu. Vì bài toán chấm điểm so frame_id với 1 khoảng [s, e] theo timeline
gốc của video, nếu frame_id chỉ là bộ đếm keyframe (0,1,2,3...) thì gần như chắc chắn sai lệch
khỏi khoảng đáp án thật của BTC dù tìm đúng khoảnh khắc. Code dưới đây dùng biến `idx` (đếm mọi
frame video, kể cả frame không lưu) làm frame_id; bộ đếm riêng `n_saved` chỉ dùng nội bộ để biết
khi nào đủ `max_frames` keyframe, KHÔNG ghi ra ngoài.

QUAN TRỌNG — nếu thiếu transnetv2-pytorch/ffmpeg: `main()` KHÔNG dừng cả batch — video nào lỗi bị
bỏ qua + ghi rõ vào danh sách in ra cuối cùng (và file `_failed_videos.txt` trong out_dir) để chạy
lại riêng sau khi cài đủ dependency, thay vì làm hỏng cả đêm chạy song song nếu 1 video gặp lỗi.

Dùng:  python extract_keyframes.py
       python extract_keyframes.py --video data/raw/xxx.mp4
"""
import argparse
import json
from pathlib import Path

import cv2
import numpy as np
import yaml
from tqdm import tqdm

VIDEO_EXTS = (".mp4", ".mkv", ".mov", ".avi", ".webm")


def load_config(config_path="config.yaml"):
    with open(config_path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def _adaptive_interval_seconds(cap, fps: float, base_interval_seconds: float, max_frames) -> float:
    """Chỉ dùng khi max_frames có giá trị (không phải None/không giới hạn). Nếu lấy mẫu cố
    định mỗi base_interval_seconds giây sẽ sinh ra nhiều hơn max_frames frame trước khi hết
    video (=> vòng lặp bị `break` giữa chừng, cắt cụt phần cuối video), tự nới khoảng lấy
    mẫu ra để trải đều đúng max_frames frame trên toàn bộ video. Video đủ ngắn thì vẫn lấy
    mẫu theo base_interval_seconds như cấu hình gốc (không đổi hành vi cũ). Không đọc được
    tổng số frame (một số container trả về 0/-1) -> giữ nguyên, chấp nhận rủi ro bị cắt cụt
    như trước thay vì đoán mò.
    """
    if max_frames is None:
        return base_interval_seconds
    total_frames = cap.get(cv2.CAP_PROP_FRAME_COUNT)
    if not total_frames or total_frames <= 0:
        return base_interval_seconds
    duration_seconds = total_frames / fps
    min_interval_to_cover_full_video = duration_seconds / max_frames
    return max(base_interval_seconds, min_interval_to_cover_full_video)


def _small_feature(frame, size: int = 16) -> np.ndarray:
    """Ảnh thu nhỏ size x size RGB, chuẩn hoá [0,1] — feature nhẹ để so similarity, không phải CLIP."""
    small = cv2.resize(frame, (size, size), interpolation=cv2.INTER_AREA)
    return small.astype(np.float32) / 255.0


def _feature_distance(a: np.ndarray, b: np.ndarray) -> float:
    """L1 distance trung bình — cùng công thức với final/extract_keyframes_method5.py."""
    return float(np.abs(a - b).mean())


def extract_keyframes_shot_similarity(
    video_path: str,
    out_dir: str,
    candidate_every_seconds: float,
    similarity_threshold: float,
    transnet_threshold: float,
    max_frames=None,
):
    """Method duy nhất: 'transnetv2_similarity' (Cách 5) — TransNetV2 chia shot + similarity
    filtering trong shot. max_frames=None (mặc định): không giới hạn, extract hết toàn bộ video.

    Raise ImportError nếu chưa cài transnetv2-pytorch, hoặc RuntimeError/lỗi khác nếu TransNetV2
    chạy lỗi — KHÔNG tự fallback về method nào khác, để lỗi lộ ra ngay thay vì âm thầm ra
    keyframe sai kiểu (xem docstring đầu file + _extract_one)."""
    from transnetv2_pytorch import TransNetV2  # import trễ: chỉ cần khi thật sự chạy hàm này

    video_id = Path(video_path).stem
    video_out_dir = Path(out_dir) / video_id
    video_out_dir.mkdir(parents=True, exist_ok=True)

    model = TransNetV2(device="auto")
    shots = model.get_scene_timestamps(video_path, threshold=transnet_threshold)
    if not shots:
        shots = [(0.0, float("inf"))]

    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        raise RuntimeError(f"Không mở được video: {video_path}")

    fps = cap.get(cv2.CAP_PROP_FPS) or 25.0
    effective_candidate_every_seconds = _adaptive_interval_seconds(cap, fps, candidate_every_seconds, max_frames)
    if effective_candidate_every_seconds > candidate_every_seconds + 1e-6:
        print(
            f"[Keyframe] {video_id}: video dài -> tự nới candidate_every_seconds "
            f"{candidate_every_seconds}s -> {effective_candidate_every_seconds:.2f}s để tránh "
            f"cắt cụt trước khi hết video trong giới hạn {max_frames} frame."
        )
    candidate_interval = max(int(round(fps * effective_candidate_every_seconds)), 1)

    frame_index = []
    n_saved = 0  # chỉ đếm số keyframe đã lưu, dùng để so với max_frames — KHÔNG ghi ra ngoài
    idx = 0
    shot_ptr = 0
    prev_feature = None

    while True:
        ret, frame = cap.read()
        if not ret:
            break
        timestamp = idx / fps

        # Sang shot mới -> reset baseline similarity (không so sánh xuyên ranh giới shot)
        while shot_ptr < len(shots) - 1 and timestamp >= shots[shot_ptr][1]:
            shot_ptr += 1
            prev_feature = None

        if idx % candidate_interval == 0:
            feature = _small_feature(frame)
            if prev_feature is None or _feature_distance(prev_feature, feature) >= similarity_threshold:
                # frame_id = idx (vị trí frame thật trong video gốc) — xem ghi chú "QUAN TRỌNG"
                # ở đầu file. Tên file ảnh cũng dùng idx để 1-1 với frame_id.
                out_path = video_out_dir / f"frame_{idx:06d}.jpg"
                cv2.imwrite(str(out_path), frame)
                frame_index.append({
                    "frame_id": idx,
                    "timestamp": round(timestamp, 2),
                    "shot_id": shot_ptr,
                    "path": str(out_path),
                    "method": "transnetv2_similarity",
                })
                n_saved += 1
                prev_feature = feature
                if max_frames is not None and n_saved >= max_frames:
                    break
        idx += 1
    cap.release()

    with open(video_out_dir / "frame_index.json", "w", encoding="utf-8") as f:
        json.dump(frame_index, f, ensure_ascii=False, indent=2)

    return video_id, frame_index


def _extract_one(video_path: str, out_dir: str, cfg: dict):
    """Luôn dùng method 'transnetv2_similarity' — không còn method nào khác, không fallback im
    lặng. Nếu thiếu transnetv2-pytorch/ffmpeg hoặc TransNetV2 lỗi lúc chạy, RAISE thẳng lỗi đó ra
    cho caller (main() bắt lỗi ở mức từng video — xem bên dưới — để 1 video lỗi không làm hỏng cả
    batch, nhưng lỗi KHÔNG bị nuốt/hạ cấp thành kết quả sai như trước)."""
    kcfg = cfg["keyframe"]
    max_frames = kcfg.get("max_frames_per_video")  # None (yaml null, mặc định) = không giới hạn

    try:
        return extract_keyframes_shot_similarity(
            video_path,
            out_dir,
            candidate_every_seconds=kcfg.get("candidate_every_seconds", 0.5),
            similarity_threshold=kcfg.get("similarity_threshold", 0.075),
            transnet_threshold=kcfg.get("transnet_threshold", 0.5),
            max_frames=max_frames,
        )
    except ImportError as e:
        raise RuntimeError(
            f"Chưa cài transnetv2-pytorch (hoặc ffmpeg) -> không trích được keyframe cho "
            f"{video_path}. Cài: pip install transnetv2-pytorch ffmpeg-python (và ffmpeg binary "
            f"qua brew/apt). Lỗi gốc: {e}"
        ) from e


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--config", default="config.yaml")
    parser.add_argument("--video", default=None, help="Chỉ chạy cho 1 video; mặc định chạy hết data/raw")
    args = parser.parse_args()

    cfg = load_config(args.config)
    raw_dir = cfg["paths"]["raw_videos"]
    out_dir = cfg["paths"]["keyframes"]

    if args.video:
        videos = [args.video]
    else:
        videos = [str(p) for p in sorted(Path(raw_dir).glob("*")) if p.suffix.lower() in VIDEO_EXTS]

    if not videos:
        print(f"Không tìm thấy video trong {raw_dir}.")
        return

    failed = []  # [(video_path, lỗi)] — 1 video lỗi không dừng cả batch, xem docstring đầu file
    for video_path in tqdm(videos, desc="Extracting keyframes"):
        try:
            video_id, frames = _extract_one(video_path, out_dir, cfg)
            print(f"[{video_id}] {len(frames)} keyframes (method=transnetv2_similarity)")
        except Exception as e:
            print(f"[Keyframe] !!! LỖI !!! Bỏ qua {video_path}: {e}")
            failed.append((video_path, str(e)))

    if failed:
        print(f"\n[Keyframe] !!! {len(failed)}/{len(videos)} video LỖI, chưa có keyframe — cần "
              f"sửa dependency (transnetv2-pytorch/ffmpeg) rồi chạy lại riêng từng video này "
              f"(--video <path>):")
        for video_path, err in failed:
            print(f"  - {video_path}: {err}")
        fail_log = Path(out_dir) / "_failed_videos.txt"
        fail_log.parent.mkdir(parents=True, exist_ok=True)
        # APPEND (không phải "w") — extract_parallel.sh/.ps1 chạy song song nhiều tiến trình
        # Python độc lập (mỗi tiến trình 1 video, qua --video), mỗi tiến trình tự gọi main()
        # riêng -> nếu dùng "w" các tiến trình sẽ ghi đè lẫn nhau, MẤT bớt dòng lỗi của các
        # video khác chạy đồng thời. extract_parallel.sh/.ps1 tự xoá file này trước khi bắt đầu
        # 1 lượt chạy mới, nên "a" ở đây vẫn an toàn (không lẫn lỗi của lần chạy cũ).
        with open(fail_log, "a", encoding="utf-8") as f:
            for video_path, err in failed:
                f.write(f"{video_path}\t{err}\n")
        print(f"[Keyframe] Danh sách video lỗi đã ghi vào {fail_log}")


if __name__ == "__main__":
    main()
