# Prompt 16 — Tài khoản và đổi mật khẩu

Bạn đang làm trên dự án Flutter Smart Farm, đồ án cuối kỳ môn Phát triển ứng dụng di động đa nền tảng, repo https://github.com/BaoThien1805/Smart_Farm.
Workspace ban đầu: C:\Users\PC\Downloads\smart_farm. Nếu đang ở checkout khác của đúng repo, dùng root hiện tại; không tự clone lại.
Đây là chat mới: khôi phục bối cảnh bằng cách đọc docs/ui-redesign-c/BRIEF.md, PROGRESS.md cùng thư mục, AGENTS.md thực sự áp dụng và code hiện tại. Không giả định lịch sử chat trước.
Người dùng chọn phong cách C: nền kem, màu pastel, icon sticker bò/heo/dê cute, thông tin dễ đọc. Chỉ làm đúng bước 16; chưa tự làm bước kế tiếp.

Điều kiện trước bước: 01, 02, 03, 15 phải có kết quả phù hợp; kiểm tra cả code thật và PROGRESS.md. Nếu chưa đủ, báo ngắn và dừng phần phụ thuộc, không tự làm cả chuỗi.
Ảnh cần MỞ XEM: docs/ui-redesign-c/reference/nhom-09.png.
Điểm bắt đầu trong code: lib/features/home/profile_page.dart; lib/features/auth/auth_controller.dart; lib/features/auth/auth_repository.dart; test/widget_test.dart; test/photo_workflow_test.dart.

## Công việc
Sửa màn 35–36: tài khoản cá nhân và đổi mật khẩu.
- Thông tin tên/email/mã/vai trò/tên trại hiển thị đúng model; không thêm địa chỉ/ngày tham gia cố định chỉ vì ảnh có.
- Ảnh thật được ưu tiên; quyền đổi avatar giữ đúng hiện tại. STAFF không có khả năng tự chỉnh thông tin mà backend chỉ cấp ADMIN.
- Form đổi mật khẩu giữ mật khẩu hiện tại/mới/xác nhận, validation đang có, show/hide, autofill, busy và thông báo lỗi.
- Giữ hành vi đổi mật khẩu thu hồi phiên/đăng nhập lại và logout xóa token; không thay TokenStore hay cơ chế lưu phiên.
- Giao diện cảm giác gần gũi nhưng thông báo bảo mật, đổi mật khẩu và đăng xuất phải rõ.
Hoàn thành khi đổi đúng/sai mật khẩu, đăng nhập lại, refresh profile và logout còn hoạt động như trước. Chạy test auth/profile/photo tương ứng và kiểm tra bàn phím trên màn nhỏ.

## Cách xử lý khi thấy chưa ổn
Áp dụng quy tắc dừng trong BRIEF.md: nếu cần đổi nghiệp vụ/API/quyền hoặc gặp vướng quan trọng, dừng phần đó và góp ý 4–6 dòng: Vướng / Ảnh hưởng / Đề xuất 1–2 cách. Hỏi một câu nếu cần quyết định. Các chi tiết UI nhỏ được tự xử lý; không hỏi xác nhận kế hoạch thông thường.

## Bàn giao
Bảo toàn thay đổi có sẵn; không hardcode số liệu mẫu vào app hoặc sửa backend cho giống ảnh. Kiểm tra đúng phạm vi, xem preview thật nếu có thể, cập nhật PROGRESS.md với bằng chứng và phần chưa xác minh. Trả lời tiếng Việt ngắn: kết quả, kiểm tra, ảnh thật, vướng mắc. Không tự commit/push/deploy.

