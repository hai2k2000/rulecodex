# Codex skill: Dọn dẹp VPS

Portable Codex skill `don-dep-vps` cho audit, dry-run, cleanup đã phê duyệt và kiểm soát phình dữ liệu sau deploy trên **nhiều VPS Linux**. Đây là skill **hướng dẫn vận hành**, không phải chương trình tự động xóa.

## Cài từ GitHub

Repository nguồn: `https://github.com/hai2k2000/rulecodex`

Sau khi clone/pull repository tại máy điều khiển Codex:

**Windows PowerShell** (không ghi đè bản đang dùng khi chưa so sánh):

```powershell
$src = "C:\path\to\rulecodex\skills\don-dep-vps"
$dst = Join-Path $HOME ".codex\skills\don-dep-vps"
# Kiểm tra/backup bản hiện có trước; chỉ copy sau khi xác nhận không mất sửa đổi riêng.
Copy-Item -Path $src -Destination $dst -Recurse
```

**Linux/macOS**:

```bash
mkdir -p "$HOME/.codex/skills"
# Nếu đã có, diff/backup rồi mới thay; không overwrite tùy tiện.
cp -R /path/to/rulecodex/skills/don-dep-vps "$HOME/.codex/skills/"
```

Khởi động lại phiên Codex hoặc refresh danh mục skills nếu cần. Gọi bằng tên `don-dep-vps`.

## Dùng cho VPS khác

1. Đảm bảo có skill/quy trình SSH riêng cho máy chủ đó; **không commit** SSH private key, mật khẩu, IP nội bộ, token, `.env`, secrets hoặc manifest chứa dữ liệu nhạy cảm.
2. Ở lần đầu, yêu cầu `don-dep-vps MODE=AUDIT`, cung cấp tên môi trường, đường dẫn root và policy retention/disk threshold **của VPS đó**. Nếu chưa biết, skill sẽ chỉ khảo sát read-only.
3. `MODE=DRY_RUN` xuất exact paths và evidence; owner duyệt trước khi `MODE=APPLY`.
4. Sau deploy, dùng `MODE=POST_DEPLOY` để đối chiếu finalizer, disk gate và retention thực tế; không tự kích hoạt deletion schedule.

Ví dụ giao nhiệm vụ:

> Dùng skill don-dep-vps, MODE=AUDIT trên VPS [tên môi trường] theo SSH skill hiện có. Kiểm tra filesystem, các thư mục build/worktree/release và nguyên nhân phình; chỉ đọc, không xóa.

Sau khi có manifest:

> Dùng skill don-dep-vps, MODE=DRY_RUN với đúng danh sách đã duyệt để xác minh candidate/rollback/reference; chưa APPLY.

**Lưu ý:** câu “dùng skill cleanup” không đồng nghĩa owner đã duyệt xóa. `APPLY` cần phê duyệt rõ chính xác đối tượng và thao tác.

## Tách cấu hình chung và riêng

Skill không hardcode: `/opt/worktrees`, `/opt/build`, `/opt/releases`, service systemd, tên Docker compose, mức free 20/30 GiB. Những giá trị này nằm trong profile/vận hành của từng VPS, được đọc từ runtime hoặc owner cung cấp.

- **Chung:** disk gate, source protection, exact allowlist, reference checks, measured recovery, giới hạn số vòng review.
- **Riêng VPS:** roots, service, rollback pointers, filesystem, CLI tooling, lock, disk budget, credentials, retention policy.

## Nguồn cải tiến v2 (2026-10-12)

Kinh nghiệm rút ra từ cleanup production:

- Stage A: 37 historical releases, thực tế thu hồi 3,205,132,288 bytes.
- Cache-only: 7 cache directories trong 4 worktrees, thực tế thu hồi 2,323,763,200 bytes.
- Kết quả thực tế đo bằng `df` thấp hơn ước tính `du`; không được tính reclaim bằng apparent size rồi cam kết.
- Worktree metadata có thể sống trong Git metadata directory, không nhất thiết nằm trong worktree.
- Tool dry-run có thể trả nhiều target hơn phạm vi owner duyệt: phải dừng, không xóa thêm mục thứ 3/38.
- Dangling symlink và permission errors trong reference inspection cần phân loại đúng thay vì bỏ qua hoặc gây chặn sai.
- Không viết thêm framework nếu tooling hiện tại có thể dùng; kết thúc khi đủ bằng chứng PASS.

Đây là tài liệu vận hành tổng quát, **không thay đổi production VPS** và không chứa thông tin truy cập.
