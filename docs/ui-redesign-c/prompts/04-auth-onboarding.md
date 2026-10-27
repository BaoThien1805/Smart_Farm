# Prompt 04 — Đăng nhập, đăng ký và chọn loài

Bạn đang làm trên dự án Flutter Smart Farm, đồ án cuối kỳ môn Phát triển ứng dụng di động đa nền tảng, repo https://github.com/BaoThien1805/Smart_Farm.
Workspace ban đầu: C:\Users\PC\Downloads\smart_farm. Nếu đang ở checkout khác của đúng repo, dùng root hiện tại; không tự clone lại.
Đây là chat mới: khôi phục bối cảnh bằng cách đọc docs/ui-redesign-c/BRIEF.md, PROGRESS.md cùng thư mục, AGENTS.md thực sự áp dụng và code hiện tại. Không giả định lịch sử chat trước.
Người dùng chọn phong cách C: nền kem, màu pastel, icon sticker bò/heo/dê cute, thông tin dễ đọc. Chỉ làm đúng bước 04; chưa tự làm bước kế tiếp.

Điều kiện trước bước: 01, 02, 03 phải có kết quả phù hợp; kiểm tra cả code thật và PROGRESS.md. Nếu chưa đủ, báo ngắn và dừng phần phụ thuộc, không tự làm cả chuỗi.
Ảnh cần MỞ XEM: docs/ui-redesign-c/reference/nhom-01.png.
Điểm bắt đầu trong code: lib/features/auth/login_page.dart; lib/features/farm/species_chooser.dart; lib/features/auth/auth_controller.dart.

## Công việc
Sửa màn 01–03: Đăng nhập, Đăng ký chủ trại và Chọn loài nuôi.
- Dùng banner và icon đã có từ bước 02; phần minh họa không đẩy ô nhập/nút chính ra ngoài khi bàn phím mở.
- Giữ đúng tên trường, password rules, hiển thị/ẩn mật khẩu, autofill, validation, chống submit lặp, thông báo lỗi và luồng đăng ký hiện có.
- Chọn loài bằng thẻ có sticker và dấu chọn, lấy danh sách thật từ API, hỗ trợ nhiều loài và khôi phục lựa chọn. Không cố định chỉ bốn loài trong dữ liệu.
- Giữ hành vi owner lần đầu phải hoàn thành setup; nhân sự không bị đưa vào thiết lập dành cho chủ.
- Không thêm quên mật khẩu, đăng nhập mạng xã hội hoặc chức năng xác thực mới.
Hoàn thành khi đăng nhập/đăng ký/chọn loài vẫn dùng controller/API cũ, màn nhỏ và bàn phím không che thao tác. Chạy test auth/species/workflow tương ứng và chụp preview thật của các màn có thể chạy local.

## Cách xử lý khi thấy chưa ổn
Áp dụng quy tắc dừng trong BRIEF.md: nếu cần đổi nghiệp vụ/API/quyền hoặc gặp vướng quan trọng, dừng phần đó và góp ý 4–6 dòng: Vướng / Ảnh hưởng / Đề xuất 1–2 cách. Hỏi một câu nếu cần quyết định. Các chi tiết UI nhỏ được tự xử lý; không hỏi xác nhận kế hoạch thông thường.

## Bàn giao
Bảo toàn thay đổi có sẵn; không hardcode số liệu mẫu vào app hoặc sửa backend cho giống ảnh. Kiểm tra đúng phạm vi, xem preview thật nếu có thể, cập nhật PROGRESS.md với bằng chứng và phần chưa xác minh. Trả lời tiếng Việt ngắn: kết quả, kiểm tra, ảnh thật, vướng mắc. Không tự commit/push/deploy.

