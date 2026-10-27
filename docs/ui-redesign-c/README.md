# Bộ prompt sửa giao diện Smart Farm phương án C

Mỗi prompt là một nhiệm vụ độc lập đủ bối cảnh để dán vào chat mới khi mở đúng repo. Thực hiện tuần tự 00 → 17, mỗi lần một bước, kiểm tra kết quả trước khi giao bước tiếp theo.
Các bước dùng chung theme, asset và một số file lớn; không mở nhiều chat sửa đồng thời cùng checkout.

## Cách dùng trong chat mới

Mở repo Smart Farm rồi dán nguyên câu sau (đổi mã bước khi cần):

```text
Dự án Smart Farm ở C:\Users\PC\Downloads\smart_farm.
Đọc docs/ui-redesign-c/README.md, BRIEF.md, PROGRESS.md và thực hiện duy nhất bước 00 theo file docs/ui-redesign-c/prompts/00-audit.md.
Mở xem các ảnh mà prompt yêu cầu. Hãy triển khai đúng phạm vi của bước được giao, kiểm tra và cập nhật tiến độ. Nếu gặp điểm chưa hợp lý ảnh hưởng chức năng/quyền/dữ liệu, dừng phần đó và góp ý ngắn theo hướng dẫn.
```

Hoặc mở từng file prompt bên dưới, copy toàn bộ nội dung và dán vào chat mới. Không cần đính kèm lại ảnh nếu chat đó có quyền đọc repo và thư mục reference/.
Nếu dùng máy khác, worktree hoặc cloud checkout, hãy mang theo toàn bộ docs/ui-redesign-c/ (ảnh cũng ở trong đây). Các file mới chưa commit không tự có trong checkout khác. Nếu không đọc được ảnh/file, cần cung cấp lại trước phần phụ thuộc; không giả định mẫu.

## Thứ tự

| Bước | Prompt để copy | Nhóm ảnh | Phụ thuộc |
|---|---|---|---|
| 00 | [Khảo sát và chốt phạm vi kỹ thuật](prompts/00-audit.md) | 01, 02, 03, 04, 05, 06, 07, 08, 09, 10, 11 | — |
| 01 | [Bộ màu và thành phần dùng chung](prompts/01-design-system.md) | 01, 02, 03, 06 | 00 |
| 02 | [Bộ icon vật nuôi và hình minh họa](prompts/02-illustrations.md) | 01, 02, 03, 06, 11 | 01 |
| 03 | [Điều hướng và màn Thêm](prompts/03-navigation-more.md) | 01, 02, 03, 10 | 01, 02 |
| 04 | [Đăng nhập, đăng ký và chọn loài](prompts/04-auth-onboarding.md) | 01 | 01, 02, 03 |
| 05 | [Tổng quan, thời tiết và vị trí trại](prompts/05-dashboard-weather.md) | 01, 10 | 01, 02, 03 |
| 06 | [Chuồng trại và danh mục](prompts/06-pens-catalogs.md) | 02 | 01, 02, 03 |
| 07 | [Danh sách và bộ lọc vật nuôi](prompts/07-animals-list-filter.md) | 03 | 01, 02, 03, 06 |
| 08 | [Hồ sơ, ảnh và lịch sử vật nuôi](prompts/08-animal-detail-history.md) | 03, 05 | 01, 02, 03, 07 |
| 09 | [Form thêm và sửa vật nuôi](prompts/09-animal-editor.md) | 03 | 01, 02, 03, 06, 08 |
| 10 | [Ghi cân, chuyển chuồng, sức khỏe và thú y](prompts/10-animal-events.md) | 04, 10 | 01, 02, 08, 09 |
| 11 | [Lịch chăm sóc và hoàn thành công việc](prompts/11-care.md) | 05 | 01, 02, 03, 08, 10 |
| 12 | [Kho, nhập xuất và lịch sử phiếu](prompts/12-inventory.md) | 06, 07 | 01, 02, 03 |
| 13 | [Thu chi, form và lịch sử chỉnh sửa](prompts/13-finance-ledger.md) | 07, 10 | 01, 02, 03 |
| 14 | [Biểu đồ, giao dịch bán và hủy bán](prompts/14-reports-sales.md) | 08 | 01, 02, 08, 13 |
| 15 | [Nhân sự và xác nhận khóa/xóa](prompts/15-personnel.md) | 09, 11 | 01, 02, 03 |
| 16 | [Tài khoản và đổi mật khẩu](prompts/16-profile.md) | 09 | 01, 02, 03, 15 |
| 17 | [Trạng thái chung và rà soát toàn bộ](prompts/17-final-review.md) | 01, 02, 03, 04, 05, 06, 07, 08, 09, 10, 11 | 04, 05, 06, 07, 08, 09, 10, 11, 12, 13, 14, 15, 16 |

## Tài liệu đi kèm

- BRIEF.md: mục tiêu, style, quy tắc giữ nghiệp vụ, khi cần dừng góp ý và tiêu chí kiểm tra.
- PROGRESS.md: ghi tiến độ để chat sau biết thật sự đã làm gì.
- reference/index.html: gallery đầy đủ 44 view; bấm PNG để xem lớn.
- reference/nhom-01.png đến nhom-11.png: ảnh nguồn cuối đã rà soát.
- PROMPTS.md: toàn bộ prompt trong một file nếu muốn lưu hoặc copy.
- MANIFEST.json: danh sách bước để tìm nhanh.

Bước 02 dành riêng cho asset. Không dùng nguyên screenshot mockup làm giao diện. Những chi tiết trong ảnh khác API/quyền hiện tại đã được lưu ý trong BRIEF.md.
Bộ tài liệu này chưa thay đổi mã app, backend hoặc dữ liệu.

## Vì sao chia như vậy

Làm nền UI và asset trước để các màn không tự chọn style khác nhau. Navigation làm sớm để không bị mất lối vào chức năng. Nhóm file có liên quan được làm cùng bước, sau cùng mới rà tổng thể và build. Mỗi bước có phần dừng góp ý với vấn đề lớn; không buộc Codex hỏi lại về padding hoặc đặt tên widget.

Nguồn hướng dẫn viết prompt: [OpenAI Docs — Prompting](https://learn.chatgpt.com/docs/prompting), [Best practices](https://learn.chatgpt.com/guides/best-practices).

