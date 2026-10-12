---
name: don-dep-vps
description: "Audit, safely reclaim disk space, and prevent repeat disk growth on Linux VPS. Covers Git worktrees, build caches, immutable releases, logs and Docker inventory using Audit/Dry-run/Apply/Post-deploy modes with explicit owner approval and protected production data."
---

# Dọn dẹp VPS — portable skill (v2, 2026-10-12)

## Khi nào dùng

Khi VPS sắp đầy ổ, build/deploy bị disk gate chặn, sau deploy còn file tạm, hoặc cần audit/retention định kỳ. Áp dụng cho **nhiều VPS**, không giả định IP, SSH user, tên service, đường dẫn, dung lượng tối thiểu hay công nghệ triển khai giống nhau.

**Nguyên tắc:** Chẩn đoán đúng → chọn mục tiêu ít rủi ro có hiệu quả → dry-run → **owner duyệt phạm vi xóa** → apply chính xác → đo lại → đóng task. Không biến cleanup thành dự án phát triển tooling.

## Khởi động — chọn MODE

- **AUDIT** (mặc định): chỉ đọc, xác định filesystem đang đầy và top consumers, nêu ứng viên.
- **DRY_RUN**: kiểm tra provenance/reference/rollback và tạo danh sách path cụ thể; không xóa.
- **APPLY**: chỉ sau phê duyệt cụ thể của owner cho **đúng tập đường dẫn + loại thao tác**. Chỉ thực hiện dưới lock, kiểm tra lại ngay trước xóa; không tự mở rộng.
- **POST_DEPLOY**: kiểm tra build/deploy finalizer, cache/retention/disk gate, hậu kiểm dịch vụ; không tự xóa nếu chưa phê duyệt.

Đọc quy định repo/AGENTS.md và skill truy cập VPS của môi trường trước khi chạy. Tác vụ từ máy điều khiển phải thao tác **trên VPS đúng mục tiêu**; không mặc định máy local chính là VPS.

## 1. Nhận diện môi trường trước khi dọn

Lấy tối thiểu: host/role (không lộ credentials), filesystem & mount chứa mục tiêu, free bytes, service health, current/previous/rollback pointers, deployment lock, danh sách worktree, cache/build/release roots và công cụ lifecycle đã tồn tại.

Các giá trị như `20 GiB hard floor` là **ví dụ theo từng dự án**, không được áp đặt cho mọi VPS. Lấy ngưỡng từ cấu hình/policy hợp lệ; nếu chưa có thì báo cần xác định budget trước build nặng hoặc xóa rủi ro. Với build/deploy: free hiện tại − peak additional disk consumption − buffer phải >= hard floor. Chỉ có free > hard floor không có nghĩa đủ chỗ build.

Không in: private key, password, session, token, secret .env hay nội dung database. Tránh liệt kê thông tin riêng tư trong log đưa lên Git.

## 2. Ưu tiên hành động theo tác động/rủi ro

1. Disposable cache rõ provenance, không được tham chiếu (vd `node_modules`, `.next` trong worktree sạch, inactive, source đã push, cache có thể tạo lại).
2. Build staging / failed-build artifacts rõ nguồn gốc, hết vòng đời theo policy.
3. Historical immutable releases **không** phải active/previous/rollback/pinned, không có reference.
4. Git worktrees đã nghỉ: clean + remote recoverable + metadata/provenance hợp lệ + không process/open FD, dùng Git-aware removal.
5. Log/journal theo quota và retention đã duyệt; backup theo policy riêng.
6. Docker chỉ **inventory/read-only** mặc định; images và nhất là volumes cần xét từng đối tượng, tuyệt đối không bulk prune.

Không xóa source chỉ vì nó cũ, to hoặc thiếu lifecycle metadata. Worktree có code uncommitted, untracked không rõ, commit chưa push hoặc đang chạy phải bảo vệ.

## 3. Bất biến an toàn cho mọi APPLY

- **Bảo vệ:** production service & data, current, previous, rollback targets (bao gồm symlink gián tiếp), release pinned/.keep/provenance/evidence, backup, DB volumes, secrets, dirty/active worktrees và các dự án khác.
- **Phạm vi chính xác:** owner duyệt tập path cụ thể; kiểm tra absolute/canonical path, root cho phép, symlink/mount escape, duplicate, parent-child overlap; không wildcard, không follow symlink để xóa.
- **Không có lỗi kiểm tra giả PASS:** inspector lỗi/permission denied/exit không mong đợi ≠ “không có reference”. Kiểm tra reference systemd/nginx/process/container đúng quyền; fail-closed khi không thể phân loại target.
- **Không mở rộng danh sách:** nếu dry-run ra 3 target nhưng owner duyệt 2, **không chạy APPLY 3**. Dùng công cụ có exact allowlist hợp lệ hoặc dừng; không “chữa cháy” bằng cleanup tràn lan.
- **Manifest:** SHA-256 chứng minh tính toàn vẹn **không thay thế** phê duyệt xóa. Khi dùng manifest, kiểm tra hash, danh sách không đổi, eligibility lại dưới lock; mismatch → STOP.
- **Concurrency:** tuân theo deploy/cleanup lock đang dùng; kiểm tra lại target/pointers/reference ngay trước mutation. Process/reference không xác minh được → STOP đối với target đó.
- **Không phá hủy hệ thống:** không `docker system prune -a`, `docker volume prune`, `git clean -fdx` trên worktree không rõ, `supabase db reset/push`, bulk deletion, xóa backup và không sửa dirty workspace.
- **Cache-only:** nếu chỉ xóa cache con, giữ nguyên Git metadata, source, package manifests/lockfile. Kiểm tra cache không phải symlink/mount/shared dependency và không được live build/service sử dụng.

Dùng **tooling có sẵn** trước; không xây engine thứ hai. Nếu tool không hỗ trợ exact target, ghi blocker và xin hướng xử lý, không lặng lẽ nới scope.

## 4. Worktree, release và reference — kinh nghiệm cần tái sử dụng

- Git worktree metadata không nhất thiết nằm trong `$worktree/.metadata`: đọc vị trí đúng từ `git rev-parse --git-path <metadata-key>` theo schema của dự án. Metadata vắng mặt/invalid/mismatch phải fail-closed; không tự adopt từ tên hoặc mtime.
- Đối chiếu `HEAD` và remote recovery, trạng thái tracked/untracked/ignored; không kết luận “clean” là toàn bộ ignored cache đều có thể xóa khi chưa kiểm tra process/reference.
- Dùng allocated bytes và free bytes thực tế: tổng `du` theo path **có thể lớn hơn** mức `df` được giải phóng do reflink/hardlink/shared blocks/open deleted files. Không cam kết chính xác số GiB sẽ thu hồi.
- Quét config chứa symlink hỏng phải phân biệt link **không liên quan** và link có khả năng tham chiếu target. Không tùy tiện dereference mọi link (vd `grep -R`) rồi coi exit lỗi là “không thấy”.
- Historical release phải kiểm tra current/previous/rollback, pin/.keep, provenance, live processes/FD, mount, systemd/nginx/container refs trước xóa.

## 5. Mỗi MODE cần trả về gì

**AUDIT:** free bytes/GiB, mục chiếm nhiều nhất (đơn vị thống nhất), ước lượng an toàn, mục chưa rõ/protected, nguyên nhân tái phát. Bounded scans; không quét vô hạn.

**DRY_RUN:** bảng `path | operation | allocated_bytes | evidence | status` (SAFE / PROTECTED / UNKNOWN); exact manifest/checksum nếu dùng; `selected/extra` và dự kiến thu hồi. UNKNOWN không được APPLY.

**APPLY:** hash/phạm vi owner duyệt, preflight under lock, số mục đã/không xóa, free bytes trước/sau, khác biệt thực tế so dự kiến, service health/pointers, lỗi. Partial failure → dừng/ghi log, không tiếp tục sang nhóm khác.

**POST_DEPLOY:** peak disk budget, temp cleanup/finalizer, bounded release/worktree/build retention, timer inventory/dry-run; phân biệt scheduler “đang chạy” với cleanup thực sự có hiệu lực. Đề xuất thay đổi nhỏ nếu cần, **không tự bật timer có tác dụng xóa**.

## 6. Kết thúc đúng lúc

- Không chạy lại cùng một audit/test sau khi PASS nếu input không thay đổi.
- Chỉ xử lý lỗi gây mất dữ liệu hoặc chặn thao tác đang được duyệt; còn lại ghi FOLLOW_UP.
- Không tiếp tục phát triển tooling chỉ để dọn vài trăm MB nếu có batch an toàn hiệu quả hơn.
- Nếu dry-run/apply bị chặn, nêu **một blocker cụ thể** và phạm vi khắc phục tối thiểu; dừng nếu phải mở rộng phê duyệt.
- Báo cáo kết quả gọn: **disk before/after, byte reclaimed, exact objects, protected unchanged, production health, remaining cause/prevention**.

Xem `references/OPERATIONS.md` để có lệnh read-only và checklist ngắn, `README.md` để cài trên VPS khác. Không dùng lệnh ví dụ khi chưa xác định đúng host/paths.
