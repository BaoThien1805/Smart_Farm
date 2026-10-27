# Prompt 09 — Form thêm và sửa vật nuôi

Bạn đang làm trên dự án Flutter Smart Farm, đồ án cuối kỳ môn Phát triển ứng dụng di động đa nền tảng, repo https://github.com/BaoThien1805/Smart_Farm.
Workspace ban đầu: C:\Users\PC\Downloads\smart_farm. Nếu đang ở checkout khác của đúng repo, dùng root hiện tại; không tự clone lại.
Đây là chat mới: khôi phục bối cảnh bằng cách đọc docs/ui-redesign-c/BRIEF.md, PROGRESS.md cùng thư mục, AGENTS.md thực sự áp dụng và code hiện tại. Không giả định lịch sử chat trước.
Người dùng chọn phong cách C: nền kem, màu pastel, icon sticker bò/heo/dê cute, thông tin dễ đọc. Chỉ làm đúng bước 09; chưa tự làm bước kế tiếp.

Điều kiện trước bước: 01, 02, 03, 06, 08 phải có kết quả phù hợp; kiểm tra cả code thật và PROGRESS.md. Nếu chưa đủ, báo ngắn và dừng phần phụ thuộc, không tự làm cả chuỗi.
Ảnh cần MỞ XEM: docs/ui-redesign-c/reference/nhom-03.png.
Điểm bắt đầu trong code: lib/features/farm/animal_editor.dart; lib/core/suggested_code_field.dart; lib/core/photo_picker.dart; test/workflow_improvements_test.dart; test/photo_workflow_test.dart.

## Công việc
Sửa màn 11: form thêm/sửa vật nuôi, dùng chung thiết kế.
- Giữ đủ toàn bộ trường hiện có dù mockup chỉ thể hiện một viewport: loài/giống, mã, tên, giới tính, các ngày, nguồn gốc, ghi chú, khu vực/chuồng, ảnh và các trường khác có trong code.
- Chia nhóm rõ, cuộn tự nhiên, nút Lưu không bị bàn phím che; label và lỗi không chỉ dựa vào placeholder.
- Giữ gợi ý mã và validation phía client/server; không bắt trường đang tùy chọn thành bắt buộc theo dấu * trong ảnh.
- Bảo toàn dữ liệu nháp khi thêm nhanh khu vực/chuồng/giống từ form. STAFF không được mở chức năng danh mục dành riêng ADMIN.
- Giữ xử lý ảnh thêm/giữ/xóa và validation kích thước; không thay đường upload.
Hoàn thành khi thêm/sửa/cancel/nhập lỗi hoạt động như cũ, không mất nháp qua form lồng, không cho lưu hai lần. Chạy các test workflow/photo/suggestion và kiểm tra bàn phím mobile.

## Cách xử lý khi thấy chưa ổn
Áp dụng quy tắc dừng trong BRIEF.md: nếu cần đổi nghiệp vụ/API/quyền hoặc gặp vướng quan trọng, dừng phần đó và góp ý 4–6 dòng: Vướng / Ảnh hưởng / Đề xuất 1–2 cách. Hỏi một câu nếu cần quyết định. Các chi tiết UI nhỏ được tự xử lý; không hỏi xác nhận kế hoạch thông thường.

## Bàn giao
Bảo toàn thay đổi có sẵn; không hardcode số liệu mẫu vào app hoặc sửa backend cho giống ảnh. Kiểm tra đúng phạm vi, xem preview thật nếu có thể, cập nhật PROGRESS.md với bằng chứng và phần chưa xác minh. Trả lời tiếng Việt ngắn: kết quả, kiểm tra, ảnh thật, vướng mắc. Không tự commit/push/deploy.

