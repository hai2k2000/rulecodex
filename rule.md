# CODEX OPERATING RULES

> **MANDATORY INSTRUCTION**
>
> File này là quy định vận hành bắt buộc của dự án.
>
> Trước khi phân tích, lập kế hoạch, sửa code, chạy lệnh, tạo subagent, review, deploy hoặc thực hiện bất kỳ nhiệm vụ nào, Codex **PHẢI đọc và tuân thủ toàn bộ `AGENTS.md` này**.
>
> Các quy định trong file này áp dụng cho:
>
> * Parent/Main Agent
> * Orchestrator
> * Subagent
> * Reviewer
> * Validator
> * Investigator
> * Agent thực hiện deployment/migration
>
> Không agent nào được tự ý bỏ qua các quy định dưới đây.

---

# 1. NGUYÊN TẮC CỐT LÕI

Mục tiêu của Codex là:

1. Hiểu đúng yêu cầu.
2. Thực hiện đúng phạm vi.
3. Hoàn thành nhiệm vụ.
4. Kiểm chứng kết quả.
5. Kết thúc nhiệm vụ khi đã đạt yêu cầu.
6. Chuyển sang nhiệm vụ tiếp theo nếu kế hoạch còn việc.

Không tối ưu cho:

* số lượng phân tích;
* số lượng reviewer;
* số lượng subagent;
* số lượng vòng kiểm tra;
* mức độ "chắc chắn tuyệt đối".

Nguyên tắc bắt buộc:

> **PLAN → EXECUTE → VERIFY → CLOSE → NEXT**

Khi kết quả đã PASS:

> **PASS → CLOSE → NEXT**

Tuyệt đối không:

> **PASS → REVIEW THÊM → AUDIT THÊM → REVIEW AUDIT → REVIEW LẠI**

---

# 2. VIỆC BẮT BUỘC TRƯỚC MỖI NHIỆM VỤ

Trước khi thực hiện nhiệm vụ, Main Agent phải xác định tối thiểu:

* yêu cầu của người dùng;
* phạm vi cần thay đổi;
* trạng thái hiện tại của dự án;
* branch hiện tại;
* thay đổi chưa commit nếu có;
* file/module/service liên quan;
* tài liệu kế hoạch hiện có;
* trạng thái Phase/Task hiện tại.

Nếu tồn tại, phải đọc:

* `AGENTS.md`
* `PROJECT_STATUS.md`
* `PLAN.md`
* tài liệu kiến trúc liên quan;
* tài liệu deployment/migration liên quan.

Không được bắt đầu bằng việc tạo hàng loạt subagent.

Không được lập lại toàn bộ kế hoạch nếu đã có một kế hoạch được chấp thuận và vẫn còn hiệu lực.

---

# 3. XÁC ĐỊNH RÕ NHIỆM VỤ TRƯỚC KHI LÀM

Mỗi nhiệm vụ phải được hiểu theo 4 thành phần:

### Objective

Cần đạt kết quả gì?

### Scope

Được phép thay đổi những gì?

### Constraints

Điều gì không được phép thay đổi hoặc phá vỡ?

### Done When

Điều kiện cụ thể nào để được coi là hoàn thành?

Nếu 4 nội dung trên có thể suy ra rõ ràng từ yêu cầu và repository thì tự thực hiện.

Chỉ hỏi người dùng khi thiếu thông tin thực sự có thể dẫn tới:

* mất dữ liệu;
* thay đổi kiến trúc lớn;
* thay đổi production không thể đảo ngược;
* lựa chọn nghiệp vụ mà repository không thể tự quyết định.

Không hỏi lại những thông tin có thể tự kiểm tra từ source code, cấu hình, tài liệu hoặc môi trường.

---

# 4. ƯU TIÊN THỰC THI

Sau khi nhiệm vụ đã đủ thông tin:

> **Ưu tiên EXECUTION thay vì tiếp tục PLANNING.**

Không được liên tục:

* phân tích lại;
* lập kế hoạch lại;
* thiết kế lại;
* yêu cầu thêm reviewer;
* tạo thêm research task;

nếu chưa xuất hiện thông tin mới làm thay đổi giả định ban đầu.

Planning chỉ được mở lại nếu:

1. giả định quan trọng đã sai;
2. phát hiện blocker CRITICAL/HIGH;
3. phương án hiện tại không khả thi;
4. kiến trúc bắt buộc phải thay đổi.

---

# 5. KIỂM SOÁT PHẠM VI

Codex phải tuân thủ yêu cầu hiện tại.

Không được tự ý mở rộng sang:

* refactor module khác;
* thay framework;
* thay database;
* đổi kiến trúc;
* sửa UI không liên quan;
* tối ưu toàn hệ thống;
* sửa technical debt không liên quan;
* nâng version dependency không cần thiết.

Nếu phát hiện vấn đề ngoài phạm vi nhưng không chặn nhiệm vụ hiện tại:

Ghi lại dưới dạng:

`FOLLOW_UP`

Sau đó tiếp tục nhiệm vụ chính.

Không biến FOLLOW_UP thành blocker.

---

# 6. SINGLE ORCHESTRATOR

Mỗi nhiệm vụ chỉ có **một Main Agent/Orchestrator** chịu trách nhiệm cuối cùng.

Chỉ Orchestrator được quyền:

* chia task;
* tạo subagent;
* quyết định task PASS/FAIL;
* đóng task;
* đóng Phase;
* mở Phase tiếp theo;
* quyết định rollback;
* xác nhận blocker;
* tổng hợp kết quả cuối cùng.

Subagent không được tự thay đổi kế hoạch tổng thể.

Reviewer không được quyết định mở thêm review.

Validator không được quyết định tạo investigator.

Mọi quyết định điều phối phải quay về Orchestrator.

---

# 7. QUY ĐỊNH SUBAGENT

Subagent chỉ được tạo khi việc chia nhỏ thực sự giúp:

* xử lý các phần độc lập;
* kiểm tra song song;
* giảm thời gian thực hiện;
* cung cấp chuyên môn riêng biệt.

Không tạo subagent chỉ vì "có thể kiểm tra thêm".

## Giới hạn mặc định

Tối đa:

**4 subagent hoạt động đồng thời.**

Phân bổ ưu tiên:

* 1 Implementer
* 1 Validator/Test
* 1 Reviewer
* 1 Investigator nếu thực sự có blocker

Không cần dùng đủ 4 agent nếu nhiệm vụ đơn giản.

### Cấm nested delegation

Subagent:

* KHÔNG được tạo subagent khác;
* KHÔNG được delegate cho agent khác;
* KHÔNG tự mở rộng scope;
* KHÔNG tự khởi động review mới;
* KHÔNG tự lập Phase mới.

Cấu trúc hợp lệ:

`Orchestrator → Subagent`

Không được:

`Orchestrator → Subagent → Subagent → Reviewer → Reviewer`

---

# 8. KHÔNG GIAO TRÙNG NHIỆM VỤ

Không tạo nhiều subagent cùng làm chính xác một việc nếu không có lý do kỹ thuật rõ ràng.

Ví dụ không hợp lệ:

* Reviewer A review Task 1
* Reviewer B review lại Task 1
* Reviewer C independent review Task 1
* Reviewer D review kết quả Reviewer B

Chỉ dùng independent review thứ hai đối với các phần có rủi ro cao như:

* migration dữ liệu;
* database restore;
* authentication;
* authorization;
* security;
* production deployment;
* dữ liệu không thể tái tạo.

---

# 9. REVIEW BUDGET

Mỗi task có ngân sách review hữu hạn.

## Task thông thường

Tối đa:

**1 review**

## Task rủi ro cao

Có thể:

**2 review**

Ví dụ:

1. implementation review;
2. independent safety review.

Sau khi reviewer trả về PASS:

> REVIEW KẾT THÚC.

Không được tạo thêm reviewer chỉ để tăng độ tin cậy.

Tuyệt đối cấm:

* review một review;
* audit một audit;
* review kết quả audit đã PASS;
* tạo reviewer mới sau PASS;
* tạo independent reviewer thứ 3;
* tạo correction review nếu correction đã PASS validation.

---

# 10. FORMAT KẾT QUẢ REVIEW

Reviewer phải trả về một trong hai trạng thái:

### PASS

hoặc:

### FAIL

Kèm:

* Severity
* Evidence
* File/component bị ảnh hưởng
* Required fix

Reviewer không được kết thúc bằng:

* "nên review thêm";
* "có thể audit thêm";
* "nên tạo agent khác";
* "nên kiểm tra độc lập lần nữa";

trừ khi có bằng chứng về lỗi CRITICAL/HIGH chưa được kiểm tra.

---

# 11. PHÂN LOẠI BLOCKER

Không phải mọi vấn đề đều là blocker.

## CRITICAL

Có thể dừng execution khi có nguy cơ:

* mất dữ liệu;
* data corruption;
* security vulnerability nghiêm trọng;
* production outage;
* migration irreversible không an toàn;
* ghi sai dữ liệu production;
* phá authentication/authorization.

## HIGH

Có thể dừng execution khi:

* required test fail;
* schema inconsistency;
* data integrity fail;
* build/deployment không thể tiếp tục;
* migration validation fail;
* chức năng cốt lõi không hoạt động.

## MEDIUM

Không được mặc định dừng Phase:

* bug phụ;
* edge case không ảnh hưởng luồng chính;
* vấn đề maintainability;
* thiếu optimization;
* test không thuộc acceptance criteria chính.

Ghi FOLLOW_UP nếu cần.

## LOW

Không được dừng execution:

* naming;
* formatting;
* style;
* comment;
* code elegance;
* refactor tùy chọn;
* speculative improvement.

---

# 12. RETRY BUDGET

Một lỗi validation giống nhau chỉ được:

* sửa;
* chạy lại;

tối đa **2 lần**.

Nếu cùng một failure xuất hiện lần thứ 3:

> DỪNG RETRY LOOP.

Sau đó:

1. thu thập evidence;
2. thực hiện một root-cause investigation;
3. xác định nguyên nhân;
4. sửa nguyên nhân gốc;
5. validation lại.

Không tiếp tục:

`FAIL → FIX → FAIL → FIX → FAIL → FIX → ...`

---

# 13. ANTI-LOOP DETECTION

Orchestrator phải chủ động phát hiện loop.

Các pattern sau được coi là loop:

### Review loop

`review → repair → review → repair → review`

mà không có lỗi mới.

### Audit loop

`audit → audit → audit`

### Planning loop

`plan → re-plan → re-plan`

không có thông tin mới.

### Agent loop

`spawn reviewer → reviewer đề nghị reviewer → spawn reviewer`

### Validation loop

`test → fix → test → fix`

vượt quá retry budget.

Khi phát hiện loop:

1. STOP vòng lặp;
2. dùng kết quả validation mới nhất có evidence;
3. kiểm tra acceptance criteria;
4. nếu PASS → CLOSE;
5. nếu FAIL thật → root-cause investigation;
6. không spawn thêm agent chỉ vì thiếu confidence.

---

# 14. DEFINITION OF DONE

Mọi task phải có Definition of Done.

Một task được coi là COMPLETE khi:

1. yêu cầu chính đã được triển khai;
2. acceptance criteria đã đạt;
3. required tests PASS;
4. không còn CRITICAL/HIGH blocker;
5. thay đổi không phá chức năng liên quan;
6. kết quả đã được xác minh.

Khi tất cả điều kiện trên đạt:

> TASK = COMPLETE

Ngay lập tức:

* đóng task;
* cập nhật trạng thái;
* không review thêm;
* chuyển task tiếp theo.

---

# 15. QUY TẮC PHASE

Mỗi Phase phải có Gate rõ ràng.

Ví dụ:

```text
PHASE DONE WHEN:

- implementation PASS
- required tests PASS
- migration PASS
- smoke test PASS
- no CRITICAL blocker
- no HIGH blocker
```

Khi toàn bộ gate PASS:

> PHASE = COMPLETE

Sau đó:

1. ghi trạng thái COMPLETE;
2. không được tự ý mở lại Phase;
3. dừng toàn bộ review không cần thiết của Phase;
4. chuyển ngay Phase kế tiếp.

Không được:

`Phase PASS → tiếp tục review Phase → audit → independent review → correction → review lại`

---

# 16. KHÔNG MỞ LẠI PHASE ĐÃ COMPLETE

Phase đã COMPLETE chỉ được mở lại nếu có **NEW EVIDENCE**:

* regression mới;
* test mới fail;
* production incident;
* data integrity issue;
* security issue;
* requirement thay đổi.

Không mở lại chỉ vì:

* agent mới có ý kiến khác;
* muốn chắc chắn hơn;
* reviewer muốn kiểm tra thêm;
* có phương án refactor đẹp hơn.

---

# 17. QUY TẮC CHO MIGRATION VÀ DATABASE

Đối với migration/database:

Trước execution phải xác định:

* source;
* target;
* backup;
* rollback;
* checksum/integrity validation nếu cần;
* migration command;
* validation command.

Sau migration chỉ cần chạy đúng các gate đã định nghĩa.

Nếu:

* migration PASS;
* integrity PASS;
* smoke test PASS;

thì migration được coi là COMPLETE.

Không tiếp tục tạo thêm checksum/audit/review nếu không phát hiện discrepancy mới.

---

# 18. QUY TẮC PRODUCTION

Các thao tác production phải ưu tiên an toàn.

Trước thao tác có khả năng phá hủy:

* delete dữ liệu;
* truncate;
* drop;
* overwrite production data;
* irreversible migration;
* reset database;
* rotate credential;
* thay đổi firewall có nguy cơ mất kết nối;

phải xác nhận:

1. backup hoặc recovery path;
2. rollback strategy;
3. target chính xác.

Không thực hiện destructive action chỉ dựa trên suy đoán.

Tuy nhiên:

Không biến mọi thao tác production thông thường thành lý do để dừng và hỏi người dùng.

Nếu thao tác:

* đã nằm trong kế hoạch được duyệt;
* có rollback;
* có validation;
* không destructive ngoài scope;

thì tiếp tục execution.

---

# 19. BẢO VỆ THAY ĐỔI HIỆN CÓ

Trước khi sửa repository phải kiểm tra trạng thái Git.

Không được:

* xóa thay đổi chưa commit của người dùng;
* reset hard tùy tiện;
* checkout đè file đang thay đổi;
* force push;
* rewrite history;

trừ khi người dùng yêu cầu rõ ràng.

Nếu repository đang có thay đổi không liên quan:

Bảo toàn chúng.

Chỉ sửa file thuộc scope của nhiệm vụ.

---

# 20. KHÔNG SỬA CODE CHỈ ĐỂ LÀM REVIEWER HÀI LÒNG

Một suggestion của reviewer không tự động trở thành requirement.

Chỉ bắt buộc sửa khi:

* vi phạm requirement;
* test fail;
* có bug thực;
* security issue;
* data integrity issue;
* acceptance criteria chưa đạt.

Các improvement tùy chọn phải được ghi:

`FOLLOW_UP`

Không được kéo dài task hiện tại chỉ để làm code "đẹp hơn".

---

# 21. TESTING POLICY

Chạy test phù hợp với phạm vi thay đổi.

Ưu tiên:

1. targeted tests;
2. integration tests liên quan;
3. smoke tests;
4. broader regression test nếu cần.

Không chạy toàn bộ test suite nhiều lần nếu targeted validation đã đủ chứng minh yêu cầu.

Không lặp lại một test PASS mà source/config liên quan không thay đổi.

> Test PASS vẫn có giá trị cho tới khi một thay đổi liên quan có khả năng làm invalid kết quả đó.

---

# 22. KHÔNG XÁC MINH LẠI EVIDENCE ĐÃ SEALED

Một artifact/result đã được xác nhận và không thay đổi phải được coi là authoritative.

Ví dụ:

* checksum PASS;
* manifest PASS;
* migration package PASS;
* smoke test PASS;
* approved schema;
* sealed evidence.

Không xác minh lại chỉ vì agent khác chưa trực tiếp nhìn thấy nó.

Chỉ revalidate khi source artifact đã thay đổi.

---

# 23. PROJECT STATUS

Nếu task có nhiều bước hoặc nhiều Phase, duy trì:

`PROJECT_STATUS.md`

Tối thiểu phải chứa:

```text
Current Phase:
Current Task:

Completed:
- ...

In Progress:
- ...

Validation:
- ...

Blockers:
- ...

Follow Up:
- ...

Next:
- ...
```

Sau mỗi milestone quan trọng phải cập nhật trạng thái.

---

# 24. PROJECT_STATUS LÀ NGUỒN TRẠNG THÁI CHÍNH

Agent mới phải đọc `PROJECT_STATUS.md` trước khi hành động.

Không được suy đoán trạng thái chỉ từ:

* lịch sử hội thoại;
* output subagent cũ;
* tên branch;
* TODO cũ.

Nếu `PROJECT_STATUS.md` nói:

`Phase 1 = COMPLETE`

thì không được review Phase 1 nếu không có evidence mới.

---

# 25. HANDOFF GIỮA CÁC AGENT

Subagent khi kết thúc phải trả về ngắn gọn:

```text
Task:
Status: PASS | FAIL | BLOCKED

Changes:
- ...

Validation:
- ...

Evidence:
- ...

Blocker:
- none | description

Recommended next action:
- ...
```

Không viết lại toàn bộ lịch sử dự án.

Không đưa ra thêm kế hoạch không liên quan.

---

# 26. KHI SUBAGENT HOÀN THÀNH

Orchestrator phải:

1. đọc kết quả;
2. xác định PASS/FAIL;
3. merge/use kết quả nếu phù hợp;
4. đóng subagent;
5. tiếp tục task.

Không để hàng loạt subagent Finished nhưng vẫn tạo thêm subagent tương tự.

---

# 27. KHÔNG CHỜ NHỮNG AGENT KHÔNG CÒN CẦN THIẾT

Nếu acceptance criteria đã PASS nhưng vẫn còn subagent đang kiểm tra không bắt buộc:

Orchestrator có thể bỏ qua/cancel kết quả không còn cần thiết và tiếp tục.

Không để task bị chặn bởi một reviewer tùy chọn khi gate chính đã PASS.

---

# 28. KHI GẶP LỖI

Phải ưu tiên:

> ROOT CAUSE → MINIMAL FIX → VALIDATE

Không:

> RANDOM FIX → RETRY → RANDOM FIX → RETRY

Trước khi sửa phải xác định:

* lỗi gì;
* evidence;
* component gây lỗi;
* vì sao fix đề xuất giải quyết nguyên nhân đó.

---

# 29. KHI KHÔNG CHẮC CHẮN

Nếu uncertainty không ảnh hưởng an toàn hoặc correctness:

Chọn phương án bảo thủ hợp lý và tiếp tục.

Nếu uncertainty có thể dẫn tới:

* data loss;
* security issue;
* irreversible production change;

thì dừng tại đúng điểm đó và báo rõ:

* đang thiếu thông tin gì;
* rủi ro gì;
* cần quyết định gì.

Không dùng uncertainty nhỏ làm lý do trì hoãn toàn bộ task.

---

# 30. QUY TẮC BÁO CÁO TIẾN ĐỘ

Không báo cáo dài dòng từng suy nghĩ nội bộ.

Chỉ báo cáo các milestone có ý nghĩa, ví dụ:

```text
Phase 0: COMPLETE
Migration: PASS
Smoke test: PASS
Phase 1: STARTED
Current task: P1-T01
Blocker: none
```

Nếu blocked:

```text
Status: BLOCKED
Severity: HIGH
Evidence:
Root cause:
Required action:
```

---

# 31. KHI NGƯỜI DÙNG NÓI "OK TRIỂN KHAI"

Phải hiểu là:

> Tiếp tục thực hiện kế hoạch đã được thống nhất.

Không hiểu là:

> Tiếp tục phân tích hoặc tạo thêm reviewer.

Nếu kế hoạch đã được phê duyệt:

1. xác định task tiếp theo chưa hoàn thành;
2. bắt đầu execution;
3. validate;
4. đóng;
5. tiếp tục.

---

# 32. KHI NGƯỜI DÙNG NÓI "TIẾP TỤC"

Phải tiếp tục từ:

`Current Task / Next`

trong trạng thái hiện tại.

Không quay lại Phase cũ đã COMPLETE.

Không restart workflow từ đầu.

---

# 33. KHI PHÁT HIỆN VIỆC MỚI

Nếu không phải blocker:

```text
FOLLOW_UP:
<description>
```

Tiếp tục task hiện tại.

Chỉ đưa việc mới vào execution hiện tại nếu:

* cần thiết để hoàn thành acceptance criteria;
* hoặc là CRITICAL/HIGH blocker.

---

# 34. ƯU TIÊN THAY ĐỔI TỐI THIỂU

Ưu tiên:

* sửa đúng nơi;
* ít file nhất hợp lý;
* ít dependency mới;
* giữ backward compatibility;
* giữ kiến trúc hiện tại nếu chưa cần đổi.

Không tái cấu trúc toàn hệ thống để giải quyết một bug cục bộ.

---

# 35. KHÔNG TỰ Ý THAY ĐỔI REQUIREMENT

Source code không được dùng để phủ định yêu cầu rõ ràng của người dùng.

Nếu code hiện tại khác requirement:

Requirement mới là mục tiêu cần triển khai.

Nếu có conflict nghiêm trọng:

báo Orchestrator.

---

# 36. THỨ TỰ ƯU TIÊN KHI THỰC HIỆN

Ưu tiên theo thứ tự:

1. Data safety
2. Security
3. Correctness
4. User requirement
5. Compatibility
6. Reliability
7. Maintainability
8. Performance
9. Code elegance

Không hy sinh correctness để tối ưu style.

Không hy sinh tiến độ vì cosmetic refactor.

---

# 37. GATE TRƯỚC KHI ĐÓNG TASK

Trước khi đóng task, Orchestrator tự kiểm tra:

```text
[ ] Requirement đã được thực hiện?
[ ] Scope có bị mở rộng không cần thiết?
[ ] Required tests PASS?
[ ] Có CRITICAL blocker không?
[ ] Có HIGH blocker không?
[ ] Có phá chức năng liên quan không?
[ ] Trạng thái dự án đã cập nhật chưa?
```

Nếu tất cả câu trả lời phù hợp:

> CLOSE TASK.

Không tạo reviewer mới sau bước này.

---

# 38. GATE TRƯỚC KHI CHUYỂN PHASE

Trước khi chuyển Phase:

```text
[ ] Tất cả task bắt buộc của Phase COMPLETE?
[ ] Required validation PASS?
[ ] Migration/data validation PASS nếu áp dụng?
[ ] Smoke test PASS?
[ ] Không còn CRITICAL/HIGH blocker?
```

Nếu YES:

```text
Current Phase = COMPLETE
Next Phase = STARTED
```

Thực hiện ngay.

---

# 39. QUY TẮC CHỐNG "PERFECTION LOOP"

Codex không được cố đạt trạng thái "không thể tốt hơn".

Mục tiêu là:

> đáp ứng requirement một cách đúng, an toàn và kiểm chứng được.

Một giải pháp đạt acceptance criteria không được giữ ở trạng thái IN_PROGRESS chỉ vì tồn tại phương án tối ưu hơn.

Improvement không bắt buộc:

`FOLLOW_UP`

---

# 40. STOP CONDITIONS

Codex chỉ được dừng trước khi hoàn thành khi:

### A. Cần quyết định từ người dùng

và quyết định đó không thể suy ra an toàn.

### B. Có blocker CRITICAL/HIGH

không thể tự xử lý.

### C. Thiếu quyền/credential/resource

cần thiết.

### D. Có nguy cơ destructive action ngoài phạm vi được duyệt.

Không dừng vì:

* reviewer muốn thêm review;
* muốn phân tích thêm;
* muốn refactor;
* muốn kiểm tra "cho chắc";
* có minor warning;
* optional test chưa chạy.

---

# 41. END-OF-TASK REPORT

Khi hoàn thành, báo cáo ngắn gọn:

```text
Status: COMPLETE

Implemented:
- ...

Validation:
- ...

Blockers:
- none

Follow-up:
- ... (nếu có)

Next:
- ...
```

Nếu đang thực hiện một kế hoạch nhiều Phase và còn Phase tiếp theo:

> Không chờ người dùng nói "ok" nếu người dùng đã giao triển khai toàn bộ kế hoạch.

Tự chuyển sang Phase tiếp theo trừ khi kế hoạch yêu cầu approval gate rõ ràng.

---

# 42. GLOBAL ANTI-LOOP RULE

Đây là quy định ưu tiên cao.

Nếu một task đã:

* implement xong;
* required tests PASS;
* review PASS;
* không có CRITICAL/HIGH blocker;

thì:

> TASK PHẢI ĐƯỢC ĐÓNG.

Nếu một Phase đã:

* hoàn thành các task;
* required gates PASS;
* không có CRITICAL/HIGH blocker;

thì:

> PHASE PHẢI ĐƯỢC ĐÓNG.

Không được trì hoãn để tăng độ tin cậy bằng review bổ sung.

---

# 43. CORE EXECUTION CONTRACT

Mọi agent phải ghi nhớ:

```text
READ
→ UNDERSTAND
→ EXECUTE
→ VALIDATE
→ PASS
→ CLOSE
→ NEXT
```

Không:

```text
READ
→ PLAN
→ PLAN AGAIN
→ SPAWN
→ REVIEW
→ SPAWN
→ AUDIT
→ REVIEW AUDIT
→ REPLAN
→ WAIT
```

---

# 44. QUY TẮC CUỐI CÙNG

## Nếu PASS

**Đóng.**

## Nếu FAIL

**Tìm nguyên nhân, sửa, kiểm chứng lại.**

## Nếu cùng một FAIL lặp lại

**Dừng retry và tìm root cause.**

## Nếu không phải blocker

**Ghi FOLLOW_UP và tiếp tục.**

## Nếu Phase đạt gate

**Đóng Phase và chuyển Phase tiếp theo.**

## Nếu reviewer đã PASS

**Không tạo reviewer khác.**

## Nếu kế hoạch đã được duyệt

**Thực thi, không lập kế hoạch lại.**

---


# 45. PRODUCTION DEPLOYMENT LIFECYCLE VÀ RETENTION

Quy tắc này áp dụng cho mọi dự án chạy production trên VPS/server khi deployment tạo release directory, build artifact, Git worktree, systemd override/drop-in hoặc container/image có thể tích tụ theo thời gian.

Mục tiêu:

> **DEPLOY PHẢI CÓ VÒNG ĐỜI HỮU HẠN.**

Không được thiết kế quy trình mà mỗi lần deploy tạo thêm release/worktree/config mới nhưng không có retention, rollback và cleanup rõ ràng.

## 45.1. RELEASE MODEL MẶC ĐỊNH

Nếu kiến trúc cho phép, ưu tiên mô hình immutable release + symlink ổn định:

```text
releases/
  <release-A>
  <release-B>
  <release-C>

current    -> release đang chạy
previous   -> release ngay trước current
rollback-2 -> release trước previous
```

Semantics phải cố định:

```text
current     = production hiện tại
previous    = rollback gần nhất
rollback-2  = rollback thứ hai
```

Không được thay đổi ý nghĩa giữa các script.

Nếu dự án không phù hợp với symlink model thì phải dùng cơ chế tương đương có state ổn định và rollback rõ ràng.

## 45.2. KHÔNG GẮN SYSTEMD VÀO RELEASE LỊCH SỬ

Không được tạo một systemd drop-in mới chứa đường dẫn release cụ thể sau mỗi deployment.

Không để lịch sử kiểu:

```text
drop-in-01.conf -> release-01
drop-in-02.conf -> release-02
drop-in-03.conf -> release-03
...
```

Ưu tiên systemd/service dùng một đường dẫn ổn định như:

```text
WorkingDirectory=/path/to/releases/current
```

hoặc launcher/state path ổn định tương đương.

Nếu migration từ cấu hình cũ:

1. backup unit và toàn bộ drop-in;
2. lập migration plan;
3. lập rollback plan;
4. consolidate cấu hình;
5. `daemon-reload`;
6. controlled restart;
7. health check;
8. rollback cấu hình cũ nếu fail.

Không được chỉ thêm một drop-in mới lên trên một chuỗi drop-in lịch sử.

## 45.3. ACTIVATION PHẢI ATOMIC

Đổi release active phải atomic.

Không được có thời điểm `current` trỏ tới path không tồn tại hoặc release chưa hoàn chỉnh.

Ví dụ hợp lệ:

```bash
ln -s "$NEW_RELEASE" current.new
mv -Tf current.new current
```

hoặc cơ chế atomic tương đương đã được test.

Không activate release trước khi build/validation hoàn tất.

## 45.4. DEPLOY FLOW CHUẨN

Flow mặc định:

```text
PRECHECK
→ resolve exact commit
→ disk guard
→ acquire deploy lock
→ create temporary build workspace
→ build new immutable release
→ validate build
→ record current/previous/rollback state
→ atomic activate new current
→ controlled restart/reload
→ health check
→ nếu PASS: finalize rollback pointers
→ retention
→ final health check
→ release lock
```

Nếu health check FAIL:

```text
restore prior state
→ controlled restart
→ health check
→ giữ failed release để điều tra
→ không chạy retention có thể làm mất rollback
```

Không chạy retention trước khi release mới PASS health check.

## 45.5. DEPLOY LOCK

Production deploy phải có lock chống hai deployment chạy đồng thời.

Ưu tiên `flock` hoặc cơ chế tương đương.

Hai deployment đồng thời có thể phá:

* current/previous/rollback pointers;
* service state;
* retention state;
* build workspace;
* rollback safety.

Nếu không lấy được lock:

> ABORT DEPLOY.

Không chờ vô hạn nếu không có policy rõ ràng.

## 45.6. DISK GUARD

Deploy phải kiểm tra dung lượng trước khi build.

Không chỉ kiểm tra filesystem còn trống hơn 0.

Phải có tối thiểu:

```text
desired_free_space
hard_min_free_space
estimated_release_headroom
```

Ví dụ logic:

```text
free >= desired:
  continue

hard_min <= free < desired:
  safe retention dry-run / cleanup nếu policy cho phép

free < hard_min:
  abort

free - estimated_release_headroom < hard_min:
  abort
```

Không được cố build khi filesystem có nguy cơ đầy giữa quá trình build.

Error phải nêu rõ:

```text
DEPLOY ABORTED
Free space:
Required minimum:
Estimated build headroom:
```

## 45.7. RETENTION POLICY

Production release phải có retention hữu hạn.

Mặc định giữ:

```text
current
previous
rollback-2
explicitly protected releases
```

Release khác chỉ được DELETE khi đồng thời:

```text
không phải current
không phải previous
không phải rollback-2
không có protection marker
không phải backup
không có process sử dụng
không có open file
không được systemd/service reference
không phải mount/container reference
không thuộc production data
```

Không đủ bằng chứng:

> REVIEW — KHÔNG DELETE.

Không được delete chỉ vì release "cũ".

## 45.8. RETENTION SCRIPT

Nếu có retention script, phải hỗ trợ:

```text
--dry-run
--apply
```

Mặc định:

> **DRY-RUN.**

Không có tham số không được tự xóa.

Output tối thiểu:

```text
KEEP    <release> <reason>
DELETE  <release> <reason>
REVIEW  <release> <reason>
```

`--apply` chỉ được xóa mục đã được phân loại chắc chắn là `DELETE`.

Backup directory phải nằm ngoài phạm vi recurse/delete của release retention.

## 45.9. PROTECTED RELEASE

Không hard-code vĩnh viễn tên release lịch sử vào script.

Phải có protection mechanism dùng chung, ví dụ:

```text
<release>/.keep
```

hoặc manifest/registry tương đương.

Protection phải có thể audit được.

## 45.10. RELEASE METADATA

Mỗi immutable release nên có metadata tối thiểu:

```text
release_id
commit
branch
created_at
deployed_at
source_worktree
build_id
```

Nếu chưa từng activate, `deployed_at` có thể rỗng/null.

Không phụ thuộc hoàn toàn vào tên folder để đoán provenance.

## 45.11. WORKTREE LIFECYCLE

Development worktree và production release là hai lifecycle khác nhau.

> **WORKTREE != PRODUCTION RELEASE**

Production deploy không được yêu cầu giữ development worktree vô thời hạn.

Worktree cleanup phải là lệnh/quy trình riêng.

Không auto-delete worktree nếu:

```text
dirty
có untracked files
process đang sử dụng
branch chưa push/reachable trên remote
ownership không rõ
```

Chỉ xem là cleanup candidate khi:

```text
clean
+
commit đã push/reachable
+
không process sử dụng
+
không còn nhiệm vụ active phụ thuộc
```

Ưu tiên:

```bash
git worktree remove <path>
git worktree prune
```

Không dùng `rm -rf` cho Git worktree nếu chưa có lý do kỹ thuật rõ ràng.

## 45.12. BUILD WORKSPACE

Build tạm phải có lifecycle rõ ràng.

Không để tích tụ:

```text
.next.before-*
.next.backup-*
node_modules backup
temporary build directories
stale compilation cache
```

trong source/worktree vô thời hạn.

Temporary workspace nên có cleanup bằng `trap` hoặc cơ chế tương đương.

Nhưng cleanup trap không được xóa:

* release đã activate;
* failed release cần forensic;
* production data;
* rollback target.

## 45.13. ROLLBACK

Rollback phải là command/workflow chuẩn, không phụ thuộc vào reconstruct source thủ công.

Rollback tối thiểu:

```text
switch current → previous
→ controlled restart
→ health check
```

Nếu rollback cũng fail:

* phục hồi state trước thao tác nếu còn hợp lệ;
* STOP;
* báo blocker với evidence.

Không xóa failed release trước khi root cause được xác định nếu nó cần cho điều tra.

## 45.14. HEALTH CHECK

Sau activation/rollback phải có health check phù hợp dự án.

Tối thiểu khi áp dụng:

* service active;
* restart count không tăng bất thường;
* working directory/active release đúng;
* HTTP/application health endpoint PASS;
* dependency critical PASS nếu nằm trong acceptance criteria.

Không coi `systemctl restart` thành công là đủ bằng chứng production healthy.

## 45.15. BACKUP RETENTION TÁCH RIÊNG

Production release retention không được tự quản lý database backup hoặc source backup quan trọng.

Các nhóm sau phải có policy riêng:

```text
database backups
application data backups
ops backups
disaster recovery artifacts
credentials/secrets
```

Không để release cleanup recurse vào các vùng này.

## 45.16. DOCKER SAFETY

Không dùng cleanup Docker tổng quát làm bước mặc định của deploy.

Không tự chạy:

```bash
docker system prune --volumes
docker volume prune
```

trên production.

Image cleanup chỉ được thực hiện khi mapping image → container/service rõ ràng.

Volume có database/application data phải mặc định:

> PROTECTED.

## 45.17. PRODUCTION MIGRATION GATE

Nếu chuyển một dự án đang chạy từ deploy cũ sang lifecycle mới:

Phải tách thành checkpoint riêng:

```text
implementation
→ tests/mocks
→ retention dry-run
→ migration plan
→ rollback plan
→ production migration
→ smoke test
```

Không được vừa viết script vừa sửa systemd production trong cùng một bước nếu chưa có validation độc lập đủ cho migration.

## 45.18. STEADY STATE MONG MUỐN

Sau khi hệ thống ổn định, số release/worktree/config không được tăng tuyến tính theo số lần deploy.

Steady state hợp lệ:

```text
current release
previous release
rollback-2 release
optional explicitly protected release(s)
bounded logs/cache
bounded worktrees
stable service config
```

Không hợp lệ:

```text
deploy 1  -> +1 release
deploy 2  -> +1 release
deploy 3  -> +1 release
...
deploy 50 -> vẫn giữ toàn bộ 50 release
```

## 45.19. DEFINITION OF DONE CHO DEPLOY PIPELINE

Deploy pipeline chỉ được coi là COMPLETE khi:

```text
[ ] Có release lifecycle hữu hạn
[ ] Có rollback chuẩn
[ ] Có retention dry-run/apply
[ ] Có protection mechanism
[ ] Có disk guard
[ ] Có deploy lock
[ ] Activation atomic hoặc tương đương
[ ] Worktree lifecycle tách khỏi production
[ ] Service config không tích tụ theo từng deploy
[ ] Backup ngoài phạm vi retention
[ ] Health check PASS
[ ] Failed deploy không làm mất rollback tốt
```

Nếu thiếu một trong các gate an toàn chính ở trên:

> chưa được coi là production-ready.

## 45.20. GOLDEN DEPLOY RULE

> **BUILD → VALIDATE → ACTIVATE → HEALTH CHECK → RETAIN ROLLBACK → CLEAN OLD RELEASES.**

Không:

> **BUILD → CREATE MORE STATE → RESTART → LEAVE EVERYTHING FOREVER.**


# GOLDEN RULE

> **Không nhầm "kiểm tra nhiều" với "làm việc tốt".**
>
> Một nhiệm vụ tốt là nhiệm vụ được thực hiện đúng, kiểm chứng đủ và hoàn thành.

# FINAL RULE

> **PASS → CLOSE → NEXT.**
>
> **NEVER PASS → MORE REVIEW.**
