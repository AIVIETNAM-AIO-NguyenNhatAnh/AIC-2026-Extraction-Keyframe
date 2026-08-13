# aic2026-keyframe-worker

Package độc lập để **từng thành viên team tự trích keyframe trên máy cá nhân** (không cần GPU,
không cần thuê server) cho 1 phần dữ liệu video AIC 2026 batch 1 — sau đó gửi kết quả về cho
trưởng nhóm gộp lại vào repo chính `aic2026-project`.

Vì sao chạy được trên máy cá nhân không cần GPU: bước trích keyframe chỉ đọc/lưu ảnh bằng
OpenCV + TransNetV2 (model nhẹ, CPU đủ dùng — xem mục "Cách 5 hoạt động thế nào" trong repo chính
`aic2026-project`), khác với các bước nặng khác của pipeline (semantic embedding, OCR/ASR quy
mô lớn) — 2 bước đó mới thực sự cần GPU và team sẽ chạy sau, riêng, trên máy thuê.

**Hỗ trợ cả macOS/Linux lẫn Windows:** mỗi bước có 2 bản script — file `.sh` (chạy bằng `bash`,
dùng trên macOS/Linux) và file `.ps1` tương ứng (chạy bằng PowerShell, dùng trên Windows). Logic
Python bên trong (`extract_keyframes.py`) dùng chung 100% cho cả 2 hệ điều hành, chỉ phần vỏ
ngoài (tải video, chạy song song, đóng gói zip) là viết riêng theo từng hệ. Xem đúng mục cho hệ
điều hành của bạn bên dưới.

## Phân công (14 file video, chia cho 5 người)

| Người | File được giao |
|---|---|
| **member1** | Videos_L21_a.zip, Videos_L22_a.zip, Videos_L23_a.zip |
| **member2** | Videos_L24_a.zip, Videos_L25_a.zip, Videos_L26_a.zip |
| **member3** | Videos_L26_b.zip, Videos_L26_c.zip, Videos_L26_d.zip |
| **member4** | Videos_L26_e.zip, Videos_L27_a.zip, Videos_L28_a.zip |
| **member5** | Videos_L29_a.zip, Videos_L30_a.zip |

Mỗi người chỉ tải và xử lý đúng phần của mình — không trùng nhau, gộp lại đủ 14/14 file.

## Cài đặt (làm 1 lần)

### macOS / Linux

1. Python 3.9+ (hầu hết Mac đã có sẵn — kiểm tra: `python3 --version`).
2. `aria2` (tải đa luồng — bắt buộc, server nguồn giới hạn tốc độ mỗi kết nối rất thấp nếu
   dùng `curl`/`wget` thường):
   ```bash
   brew install aria2      # macOS
   apt install -y aria2    # Linux/WSL
   ```
3. `ffmpeg` (bắt buộc — method trích keyframe duy nhất "transnetv2_similarity" cần binary này
   để đọc video, thông qua gói Python `ffmpeg-python`):
   ```bash
   brew install ffmpeg      # macOS
   apt install -y ffmpeg    # Linux/WSL
   ```
4. Không cần tự cài các gói Python (opencv/pyyaml/tqdm/transnetv2-pytorch/ffmpeg-python) — script
   tự phát hiện Python và tự cài thiếu gì bù nấy theo `requirements.txt` (xem `_common.sh`). Lần
   chạy đầu sẽ tải thêm weight TransNetV2 (vài chục MB, bundle sẵn trong gói `transnetv2-pytorch`,
   không cần tải riêng) — cần mạng ổn định lúc đó.

### Windows

1. Python 3.9+ — tải từ [python.org](https://python.org) (nhớ tick "Add python.exe to PATH" lúc
   cài) hoặc `winget install Python.Python.3.11`. Kiểm tra: mở PowerShell, gõ `py -3.11 --version`.
2. `aria2` (tải đa luồng):
   ```powershell
   winget install aria2.aria2
   ```
3. `ffmpeg` (bắt buộc — giống lý do ở mục macOS/Linux):
   ```powershell
   winget install ffmpeg
   ```
   (nếu máy không có `winget`, cài qua [Chocolatey](https://chocolatey.org): `choco install aria2 ffmpeg`,
   hoặc tải thủ công 2 file `.exe`/`.zip` từ trang chủ rồi thêm đường dẫn vào biến môi trường `PATH`)
4. Cho phép chạy file `.ps1` (Windows mặc định chặn) — mở PowerShell **với quyền người dùng hiện
   tại** (không cần Admin), gõ 1 lần:
   ```powershell
   Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
   ```
5. Không cần tự cài gói Python (opencv/pyyaml/tqdm/transnetv2-pytorch/ffmpeg-python) — script
   `.ps1` tự phát hiện Python và tự cài thiếu gì bù nấy, giống hệt bản macOS/Linux.

## Chạy (chỉ 1 lệnh)

Thay `memberN` bằng đúng phần bạn được giao (`member1`..`member5`):

**macOS/Linux** — mở Terminal, `cd` vào thư mục này:
```bash
bash run_all.sh member1
```

**Windows** — mở PowerShell, `cd` vào thư mục này:
```powershell
.\run_all.ps1 member1
```

Lệnh này tự làm tuần tự:
1. Tải + giải nén video được giao vào `data/raw/` (xoá zip ngay sau khi giải nén, đỡ tốn đĩa).
2. Trích keyframe **song song nhiều video cùng lúc** (tận dụng nhiều core CPU) vào
   `data/keyframes/{video_id}/`.
3. Nén `data/keyframes/` thành 1 file `keyframes_memberN_<ngày giờ>.zip`.

Xong thì gửi file zip đó (Zalo/Google Drive/email) cho trưởng nhóm.

**Kiểm tra lại trước khi gửi (quan trọng):** chỉ có 1 method "transnetv2_similarity" (Cách 5),
không còn method dự phòng nào khác. Nếu máy bạn thiếu `ffmpeg`/`transnetv2-pytorch` hoặc cài lỗi,
video đó sẽ LỖI hẳn (không ra keyframe) — 1 video lỗi không làm dừng cả batch, các video khác vẫn
chạy tiếp bình thường, nhưng video lỗi sẽ được liệt kê rõ ở cuối log và ghi vào
`data/keyframes/_failed_videos.txt`. Kiểm tra nhanh trước khi gửi:
```bash
cat data/keyframes/_failed_videos.txt 2>/dev/null
```
```powershell
Get-Content data\keyframes\_failed_videos.txt -ErrorAction SilentlyContinue
```
Nếu file này tồn tại và có nội dung, nghĩa là còn video chưa có keyframe — xem lỗi cụ thể trong
đó (thường là thiếu `ffmpeg`/`transnetv2-pytorch`), cài đủ rồi chạy lại đúng video đó
(`python3 extract_keyframes.py --video data/raw/xxx.mp4` hoặc trên Windows `py -3.11
extract_keyframes.py --video data\raw\xxx.mp4`) trước khi gửi.

**Thời gian ước tính:** phụ thuộc số lượng + độ dài video trong phần được giao và số core máy
— tổng dữ liệu càng chia đều nhau càng nhanh gộp lại. Có thể chạy nền qua đêm, không cần ngồi
canh, nhưng máy sẽ dùng nhiều CPU trong lúc chạy.

## Chạy từng bước riêng (nếu cần)

**macOS/Linux:**
```bash
bash download_videos.sh member1     # chỉ tải
bash extract_parallel.sh            # chỉ trích keyframe (mặc định số luồng = số core máy - 1)
bash extract_parallel.sh 4          # ép chạy đúng 4 video song song
bash package_results.sh member1     # chỉ đóng gói
```

**Windows:**
```powershell
.\download_videos.ps1 member1        # chỉ tải
.\extract_parallel.ps1               # chỉ trích keyframe (mặc định số luồng = số core máy - 1)
.\extract_parallel.ps1 4             # ép chạy đúng 4 video song song
.\package_results.ps1 member1        # chỉ đóng gói
```

Nếu chạy `.ps1` báo lỗi kiểu "không thể tải vì không được ký số" / "running scripts is disabled
on this system" — đó là chính sách Execution Policy mặc định của Windows, xem lại bước 4 ở mục
Cài đặt phía trên. Nếu vẫn không đổi được (máy công ty/trường bị khoá chính sách), chạy tạm 1 lần
không cần đổi policy vĩnh viễn:
```powershell
powershell -ExecutionPolicy Bypass -File .\run_all.ps1 member1
```

## Dành cho trưởng nhóm — gộp kết quả lại vào repo chính

Sau khi nhận đủ 5 file zip từ team, giải nén từng file rồi copy đè thư mục `data/keyframes/`
của từng người vào `aic2026-project/data/keyframes/` (không trùng `video_id` giữa các người nên
copy đè an toàn, không mất dữ liệu):

```bash
cd aic2026-project
for f in keyframes_member*.zip; do
  unzip -o -q "$f" -d /tmp/kf_merge
  cp -R /tmp/kf_merge/data/keyframes/. data/keyframes/
  rm -rf /tmp/kf_merge
done
ls data/keyframes | wc -l   # kiểm tra đủ số video
```

Sau đó chạy tiếp các bước còn lại của pipeline (ASR/OCR/color/semantic + build index) trên máy
đã thuê GPU, đọc thẳng `data/keyframes/` đã gộp — không cần trích lại keyframe nữa vì output đã
cùng schema (`data/keyframes/{video_id}/frame_{frame_id:06d}.jpg` + `frame_index.json`) như
`indexing/keyframe_extraction.py` trong repo chính.

## Lưu ý cấu hình

`config.yaml` trong package này set sẵn giống hệt mặc định của `aic2026-project` (method
`transnetv2_similarity` — Cách 5, `max_frames_per_video: null` — không giới hạn). **Không đổi
giá trị trong file này** trừ khi cả team thống nhất đổi chung, vì lệch cấu hình giữa các máy sẽ
khiến keyframe của từng phần không đồng nhất (method/mật độ frame khác nhau) khi gộp lại.

## Metadata frame_id lưu ở đâu, đúng chuẩn BTC chưa

Mỗi keyframe lưu trong `data/keyframes/{video_id}/frame_index.json` (đi kèm ảnh `frame_{frame_id:06d}.jpg`
trong cùng thư mục), mỗi phần tử gồm:
```json
{"frame_id": 340, "timestamp": 13.6, "shot_id": 2,
 "path": "data/keyframes/L21_V001/frame_000340.jpg",
 "method": "transnetv2_similarity"}
```
`frame_id` LUÔN là vị trí frame thật trong video gốc (đếm tuần tự từ 0 theo đúng frame rate gốc,
không phải số thứ tự keyframe) — đúng định dạng BTC yêu cầu khi nộp `<video_id>, <frame_id>`
(xem "Thông tin vòng Sơ tuyển AIC2026.pdf" mục 2.1). Trường `method` luôn là `"transnetv2_similarity"`
(không còn giá trị nào khác có thể xuất hiện) — nếu 1 video KHÔNG trích được bằng Cách 5, nó sẽ
không có `frame_index.json` nào cả và được liệt kê trong `data/keyframes/_failed_videos.txt` thay
vì âm thầm ra 1 bộ keyframe sai kiểu — xem mục "Kiểm tra lại trước khi gửi" ở trên.
