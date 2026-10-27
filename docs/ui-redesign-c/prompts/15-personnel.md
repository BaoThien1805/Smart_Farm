# Prompt 15 — Nhân sự và xác nhận khóa/xóa

Bạn đang làm trên dự án Flutter Smart Farm, đồ án cuối kỳ môn Phát triển ứng dụng di động đa nền tảng, repo https://github.com/BaoThien1805/Smart_Farm.
Workspace ban đầu: C:\Users\PC\Downloads\smart_farm. Nếu đang ở checkout khác của đúng repo, dùng root hiện tại; không tự clone lại.
Đây là chat mới: khôi phục bối cảnh bằng cách đọc docs/ui-redesign-c/BRIEF.md, PROGRESS.md cùng thư mục, AGENTS.md thực sự áp dụng và code hiện tại. Không giả định lịch sử chat trước.
Người dùng chọn phong cách C: nền kem, màu pastel, icon sticker bò/heo/dê cute, thông tin dễ đọc. Chỉ làm đúng bước 15; chưa tự làm bước kế tiếp.

Điều kiện trước bước: 01, 02, 03 phải có kết quả phù hợp; kiểm tra cả code thật và PROGRESS.md. Nếu chưa đủ, báo ngắn và dừng phần phụ thuộc, không tự làm cả chuỗi.
Ảnh cần MỞ XEM: docs/ui-redesign-c/reference/nhom-09.png; docs/ui-redesign-c/reference/nhom-11.png.
Điểm bắt đầu trong code: lib/features/users/users_page.dart; lib/features/users/users_controller.dart; lib/features/auth/user_avatar.dart; test/personnel_edit_test.dart; test/roles_test.dart.

## Công việc
Sửa màn 33, 34, 43, 44: danh sách nhân sự, form thêm/sửa, xác nhận khóa/mở khóa và xóa.
- Dùng avatar người thật nếu có, fallback trung tính cho con người; không dùng icon bò/heo đại diện cho nhân sự.
- Hiện mã, tên, email, vai trò và trạng thái; thao tác ADMIN và bảo vệ tài khoản chủ theo code. Không thêm vai trò hay cho tạo ADMIN mới.
- Form giữ khác biệt thêm/sửa, ảnh, gợi ý mã và validation mật khẩu ban đầu đang có. Không xuất mật khẩu thật ra log/screenshot.
- Khóa/mở khóa/xóa giải thích hậu quả ngắn, phân biệt xóa vật lý nếu chưa lịch sử và xóa mềm nếu đã liên kết. Không nói luôn luôn xóa dữ liệu hoặc luôn luôn giữ tài khoản.
- Modal khóa/xóa phải độc lập; không sao chép ảnh 44 thành hai modal/form đồng thời.
Hoàn thành khi sửa role/email/ảnh đúng luồng, bảo vệ chủ, thu hồi phiên và giữ lịch sử được giữ nguyên. Chạy test personnel/edit/roles liên quan; không tự tạo thêm filter cần endpoint mới.

## Cách xử lý khi thấy chưa ổn
Áp dụng quy tắc dừng trong BRIEF.md: nếu cần đổi nghiệp vụ/API/quyền hoặc gặp vướng quan trọng, dừng phần đó và góp ý 4–6 dòng: Vướng / Ảnh hưởng / Đề xuất 1–2 cách. Hỏi một câu nếu cần quyết định. Các chi tiết UI nhỏ được tự xử lý; không hỏi xác nhận kế hoạch thông thường.

## Bàn giao
Bảo toàn thay đổi có sẵn; không hardcode số liệu mẫu vào app hoặc sửa backend cho giống ảnh. Kiểm tra đúng phạm vi, xem preview thật nếu có thể, cập nhật PROGRESS.md với bằng chứng và phần chưa xác minh. Trả lời tiếng Việt ngắn: kết quả, kiểm tra, ảnh thật, vướng mắc. Không tự commit/push/deploy.

