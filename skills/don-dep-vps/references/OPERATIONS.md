# Operational field guide — don-dep-vps

Chỉ chạy trên VPS đúng mục tiêu, sau khi đọc repo/SSH skill. Đây là **mẫu lệnh khảo sát read-only**, không phải script APPLY tự động. Thay `<...>` bằng giá trị đã xác minh; không chạy nguyên placeholder.

## 1. Inventory nhanh

```bash
hostname
df -B1 -P /
findmnt -T /opt -o TARGET,SOURCE,FSTYPE,OPTIONS
# Thay thoidai-work bằng tên service thực tế nếu có
systemctl show <SERVICE> -p ActiveState -p ExecMainStatus -p NRestarts
```

`df -B1` đo free bytes của filesystem, không phải tổng có thể thu hồi. Dùng cùng mount để so sánh trước/sau. Không giả định `/opt` nằm chung filesystem với `/`.

## 2. Bounded directory measurements

```bash
du -sx -B1 -- <WORKTREE_ROOT> <BUILD_ROOT> <RELEASE_ROOT>
du -sx --apparent-size -B1 -- <CANDIDATE_PATH>
du -sx -B1 -- <CANDIDATE_PATH>
```

`du` có thể tốn thời gian trên cây lớn: đo các root đã biết, tránh `du /` hoặc `find /` tràn lan. Allocated/apparent và `df` delta có thể khác nhau do reflinks/shared blocks/open deleted files.

## 3. Worktree recovery và metadata

```bash
git -C <REPO> worktree list --porcelain
git -C <WORKTREE> status --porcelain=v1 --untracked-files=all
git -C <WORKTREE> rev-parse HEAD
git -C <WORKTREE> rev-parse --verify '@{upstream}'
git -C <WORKTREE> rev-parse --git-path <LIFECYCLE_METADATA_KEY>
```

Kiểm tra ignored directories riêng (vd `git check-ignore`) và xác minh `node_modules/.next` không phải symlink/mount/shared asset. “Git clean” không bao phủ dữ liệu ignored hoặc unpublished nếu không kiểm tra remote recovery.

## 4. Release/pointers và references

```bash
readlink -f -- <CURRENT_POINTER>
readlink -f -- <PREVIOUS_POINTER>
readlink -f -- <ROLLBACK_POINTER>
findmnt -T <CANDIDATE_PATH> -o TARGET,SOURCE,FSTYPE
```

Kiểm tra pin/.keep/provenance, live process references, open FD, symlink and service config. Nếu công cụ thiếu quyền hoặc inspector lỗi, đừng suy ra không có reference. Khi tìm text trong config trees, phân biệt symlink hỏng ngoài scope với link có thể tham chiếu target; `grep -R` dereference symlink và có thể gây exit 2.

## 5. Lập quyết định cleanup

```text
path | operation | allocated_bytes | git/provenance | references | status
/verified/absolute/path | remove-cache-only | N | clean+remote | none verified | SAFE
/... | keep | N | missing evidence | unknown | UNKNOWN
```

SAFE cần đủ điều kiện cho **đúng thao tác**; ví dụ đủ điều kiện xóa cache không có nghĩa được xóa parent worktree.

Nếu tool có manifest, gắn SHA256 và owner-approved exact path list. Không coi SHA256 là ủy quyền. Nếu tool định xóa thêm đường dẫn ngoài danh sách, STOP. APPLY chỉ chạy theo công cụ phù hợp và dưới lock, revalidation ngay trước deletion.

## 6. Post-cleanup acceptance

```bash
df -B1 -P <MOUNT_OR_PATH>
systemctl show <SERVICE> -p ActiveState -p ExecMainStatus -p NRestarts
# Kiểm tra HTTP endpoint theo policy của VPS; không in auth token
```

Báo cáo: free bytes before/after, reclaimed bytes = after − before (ghi rõ nếu thay đổi nền/concurrent write), số lượng SAFE/APPLIED/SKIPPED, service health, protected pointers và FOLLOW_UP cho root cause. Không tuyên bố production PASS khi chưa kiểm tra.

## 7. Tránh tái phình

- Build/deploy: disk gate trước thao tác nặng dựa trên **peak additional bytes + safety buffer**.
- Failed-build: finalizer thu hồi staging khi không còn process/reference.
- Worktree: giữ metadata/recovery, dọn cache của worktree inactive trước khi cân nhắc xóa source.
- Release: bounded retention sau deploy, bảo vệ rollback/pinned.
- Timer: daily inventory/weekly dry-run tùy policy, không bật APPLY timer khi chưa owner duyệt.
- STOP sau một lần đạt acceptance; không làm thêm audit/review vô hạn.
