# Prompt 11 — Lịch chăm sóc và hoàn thành công việc

Bạn đang làm trên dự án Flutter Smart Farm, đồ án cuối kỳ môn Phát triển ứng dụng di động đa nền tảng, repo https://github.com/BaoThien1805/Smart_Farm.
Workspace ban đầu: C:\Users\PC\Downloads\smart_farm. Nếu đang ở checkout khác của đúng repo, dùng root hiện tại; không tự clone lại.
Đây là chat mới: khôi phục bối cảnh bằng cách đọc docs/ui-redesign-c/BRIEF.md, PROGRESS.md cùng thư mục, AGENTS.md thực sự áp dụng và code hiện tại. Không giả định lịch sử chat trước.
Người dùng chọn phong cách C: nền kem, màu pastel, icon sticker bò/heo/dê cute, thông tin dễ đọc. Chỉ làm đúng bước 11; chưa tự làm bước kế tiếp.

Điều kiện trước bước: 01, 02, 03, 08, 10 phải có kết quả phù hợp; kiểm tra cả code thật và PROGRESS.md. Nếu chưa đủ, báo ngắn và dừng phần phụ thuộc, không tự làm cả chuỗi.
Ảnh cần MỞ XEM: docs/ui-redesign-c/reference/nhom-05.png.
Điểm bắt đầu trong code: lib/features/farm/farm_pages.dart: CarePage and care forms; lib/features/farm/farm_widgets.dart; test/roles_test.dart; test/phase_4_test.dart.

## Công việc
Sửa màn 17–19: danh sách lịch, form đặt/sửa và form hoàn thành; dùng thiết kế lịch sử đã có ở bước 08.
- Nhóm công việc theo ngày, có nhãn quá hạn và trạng thái chờ/hoàn thành/đã hủy từ dữ liệu thật. Không gán giờ 09:00 khi API chỉ lưu ngày.
- Hai loại công việc hiện có là VACCINATION và CHECKUP. Không thêm loại Chăm sóc chung chỉ vì ảnh cũ có ô đó.
- Giữ các thao tác đặt/sửa/hủy theo quyền; STAFF lập lịch được nhưng không xác nhận hoàn thành. ADMIN/VET mới có thao tác hoàn thành hợp lệ.
- Hoàn thành có ngày thực tế, kết quả và sức khỏe theo model hiện tại; không biến nút bắt đầu thành tính năng quy trình mới chưa có.
- Không ghi chẩn đoán tự động, không sửa lịch đã đóng hoặc gửi lặp.
Hoàn thành khi trạng thái/chỉ số/dashboard cập nhật đúng sau thao tác, form chống submit lặp và quyền rõ ràng. Chạy test care/roles hiện có; kiểm tra các trạng thái không có lịch và lịch dài.

## Cách xử lý khi thấy chưa ổn
Áp dụng quy tắc dừng trong BRIEF.md: nếu cần đổi nghiệp vụ/API/quyền hoặc gặp vướng quan trọng, dừng phần đó và góp ý 4–6 dòng: Vướng / Ảnh hưởng / Đề xuất 1–2 cách. Hỏi một câu nếu cần quyết định. Các chi tiết UI nhỏ được tự xử lý; không hỏi xác nhận kế hoạch thông thường.

## Bàn giao
Bảo toàn thay đổi có sẵn; không hardcode số liệu mẫu vào app hoặc sửa backend cho giống ảnh. Kiểm tra đúng phạm vi, xem preview thật nếu có thể, cập nhật PROGRESS.md với bằng chứng và phần chưa xác minh. Trả lời tiếng Việt ngắn: kết quả, kiểm tra, ảnh thật, vướng mắc. Không tự commit/push/deploy.

