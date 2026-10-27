# Prompt 12 — Kho, nhập xuất và lịch sử phiếu

Bạn đang làm trên dự án Flutter Smart Farm, đồ án cuối kỳ môn Phát triển ứng dụng di động đa nền tảng, repo https://github.com/BaoThien1805/Smart_Farm.
Workspace ban đầu: C:\Users\PC\Downloads\smart_farm. Nếu đang ở checkout khác của đúng repo, dùng root hiện tại; không tự clone lại.
Đây là chat mới: khôi phục bối cảnh bằng cách đọc docs/ui-redesign-c/BRIEF.md, PROGRESS.md cùng thư mục, AGENTS.md thực sự áp dụng và code hiện tại. Không giả định lịch sử chat trước.
Người dùng chọn phong cách C: nền kem, màu pastel, icon sticker bò/heo/dê cute, thông tin dễ đọc. Chỉ làm đúng bước 12; chưa tự làm bước kế tiếp.

Điều kiện trước bước: 01, 02, 03 phải có kết quả phù hợp; kiểm tra cả code thật và PROGRESS.md. Nếu chưa đủ, báo ngắn và dừng phần phụ thuộc, không tự làm cả chuỗi.
Ảnh cần MỞ XEM: docs/ui-redesign-c/reference/nhom-06.png; docs/ui-redesign-c/reference/nhom-07.png.
Điểm bắt đầu trong code: lib/features/farm/inventory_page.dart; lib/features/farm/farm_widgets.dart; test/phase_4_test.dart; test/roles_test.dart.

## Công việc
Sửa màn 21–26: tồn kho, thêm/sửa thức ăn, nhập/xuất, lịch sử và hủy phiếu.
- Dùng minh họa bao thức ăn nhỏ, số kg dễ đọc, nhãn tồn thấp có text và màu. Chỉ hiện cảnh báo khi dữ liệu/logic tồn thấp thật đáp ứng.
- Giữ tab, filter, phân trang, đơn vị kg, precision và form đang có. Không thêm đơn giá/dự báo ngày hết vì model kho hiện chưa có.
- Nhập/xuất dùng dữ liệu thật; xuất có chuồng không bắt buộc. Nếu hiển thị tồn sau xuất, tính từ giá trị hợp lệ trong form, không thay kiểm tra server.
- Chủ/nhân viên thao tác theo quyền hiện có; hủy phiếu ADMIN, có lý do và không xóa lịch sử.
- Tồn 0, số thập phân dài, phiếu đã hủy và giao dịch bị server từ chối phải hiển thị rõ; không tô mọi phiếu là thành công.
Hoàn thành khi luồng nhập/xuất/hủy vẫn dùng API/requestId cũ, kiểm tra tồn âm không bị bỏ qua và trạng thái refresh đúng. Chạy test kho/UI liên quan; dùng local/test fixture khi kiểm tra thao tác ghi.

## Cách xử lý khi thấy chưa ổn
Áp dụng quy tắc dừng trong BRIEF.md: nếu cần đổi nghiệp vụ/API/quyền hoặc gặp vướng quan trọng, dừng phần đó và góp ý 4–6 dòng: Vướng / Ảnh hưởng / Đề xuất 1–2 cách. Hỏi một câu nếu cần quyết định. Các chi tiết UI nhỏ được tự xử lý; không hỏi xác nhận kế hoạch thông thường.

## Bàn giao
Bảo toàn thay đổi có sẵn; không hardcode số liệu mẫu vào app hoặc sửa backend cho giống ảnh. Kiểm tra đúng phạm vi, xem preview thật nếu có thể, cập nhật PROGRESS.md với bằng chứng và phần chưa xác minh. Trả lời tiếng Việt ngắn: kết quả, kiểm tra, ảnh thật, vướng mắc. Không tự commit/push/deploy.

