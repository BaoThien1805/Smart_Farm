# Prompt 10 — Ghi cân, chuyển chuồng, sức khỏe và thú y

Bạn đang làm trên dự án Flutter Smart Farm, đồ án cuối kỳ môn Phát triển ứng dụng di động đa nền tảng, repo https://github.com/BaoThien1805/Smart_Farm.
Workspace ban đầu: C:\Users\PC\Downloads\smart_farm. Nếu đang ở checkout khác của đúng repo, dùng root hiện tại; không tự clone lại.
Đây là chat mới: khôi phục bối cảnh bằng cách đọc docs/ui-redesign-c/BRIEF.md, PROGRESS.md cùng thư mục, AGENTS.md thực sự áp dụng và code hiện tại. Không giả định lịch sử chat trước.
Người dùng chọn phong cách C: nền kem, màu pastel, icon sticker bò/heo/dê cute, thông tin dễ đọc. Chỉ làm đúng bước 10; chưa tự làm bước kế tiếp.

Điều kiện trước bước: 01, 02, 08, 09 phải có kết quả phù hợp; kiểm tra cả code thật và PROGRESS.md. Nếu chưa đủ, báo ngắn và dừng phần phụ thuộc, không tự làm cả chuỗi.
Ảnh cần MỞ XEM: docs/ui-redesign-c/reference/nhom-04.png; docs/ui-redesign-c/reference/nhom-10.png.
Điểm bắt đầu trong code: lib/features/farm/farm_pages.dart: AnimalDetailPage.event; lib/features/farm/farm_widgets.dart; test/roles_test.dart; test/farm_test.dart.

## Công việc
Sửa các form màn 13–16 và 40: ghi cân, chuyển chuồng, quan sát sức khỏe, khám thú y, ghi nhận chết.
- Dùng header cá thể gọn, trường nhập rõ, nút xác nhận phù hợp mức độ thao tác.
- Cân nặng giữ độ chính xác tối đa ba số lẻ theo luồng hiện tại; giữ parse/format không đổi 215,500 thành 215500 kg. Chuồng đích chỉ hiển thị lựa chọn đúng trạng thái/sức chứa.
- Quan sát sức khỏe và khám là hai nghiệp vụ khác nhau. STAFF được quan sát nhưng không được ghi chẩn đoán. Chẩn đoán trong khám thú y bắt buộc theo code; điều trị theo quy tắc hiện có.
- Hai tình trạng sức khỏe là NORMAL/NEEDS_CARE; tên hiển thị tương đương Bình thường/Cần chăm sóc. Không tạo thêm trạng thái từ ảnh.
- Ghi nhận chết chỉ ADMIN khi hợp lệ, có xác nhận rõ hậu quả; giữ lịch sử và callback hiện có.
- Chỉ trình bày chênh lệch cân nếu có dữ liệu trước đó và tính được chính xác; không thêm dự báo/AI.
Hoàn thành khi các quyền, validation, requestId và cập nhật hồ sơ được giữ nguyên. Chạy các test form/role/nghiệp vụ có liên quan; không sửa backend để hợp mockup.

## Cách xử lý khi thấy chưa ổn
Áp dụng quy tắc dừng trong BRIEF.md: nếu cần đổi nghiệp vụ/API/quyền hoặc gặp vướng quan trọng, dừng phần đó và góp ý 4–6 dòng: Vướng / Ảnh hưởng / Đề xuất 1–2 cách. Hỏi một câu nếu cần quyết định. Các chi tiết UI nhỏ được tự xử lý; không hỏi xác nhận kế hoạch thông thường.

## Bàn giao
Bảo toàn thay đổi có sẵn; không hardcode số liệu mẫu vào app hoặc sửa backend cho giống ảnh. Kiểm tra đúng phạm vi, xem preview thật nếu có thể, cập nhật PROGRESS.md với bằng chứng và phần chưa xác minh. Trả lời tiếng Việt ngắn: kết quả, kiểm tra, ảnh thật, vướng mắc. Không tự commit/push/deploy.

