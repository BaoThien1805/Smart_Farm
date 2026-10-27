# Prompt 03 — Điều hướng và màn Thêm

Bạn đang làm trên dự án Flutter Smart Farm, đồ án cuối kỳ môn Phát triển ứng dụng di động đa nền tảng, repo https://github.com/BaoThien1805/Smart_Farm.
Workspace ban đầu: C:\Users\PC\Downloads\smart_farm. Nếu đang ở checkout khác của đúng repo, dùng root hiện tại; không tự clone lại.
Đây là chat mới: khôi phục bối cảnh bằng cách đọc docs/ui-redesign-c/BRIEF.md, PROGRESS.md cùng thư mục, AGENTS.md thực sự áp dụng và code hiện tại. Không giả định lịch sử chat trước.
Người dùng chọn phong cách C: nền kem, màu pastel, icon sticker bò/heo/dê cute, thông tin dễ đọc. Chỉ làm đúng bước 03; chưa tự làm bước kế tiếp.

Điều kiện trước bước: 01, 02 phải có kết quả phù hợp; kiểm tra cả code thật và PROGRESS.md. Nếu chưa đủ, báo ngắn và dừng phần phụ thuộc, không tự làm cả chuỗi.
Ảnh cần MỞ XEM: docs/ui-redesign-c/reference/nhom-01.png; docs/ui-redesign-c/reference/nhom-02.png; docs/ui-redesign-c/reference/nhom-03.png; docs/ui-redesign-c/reference/nhom-10.png.
Điểm bắt đầu trong code: lib/features/home/workspace_page.dart; lib/features/auth/auth_repository.dart; test/roles_test.dart.

## Công việc
Đổi bố cục điều hướng mobile sang 5 mục của C: Tổng quan, Chuồng trại, Vật nuôi, Lịch, Thêm.
- Tạo màn Thêm với lối vào Kho thức ăn, Thu chi, Nhân sự, Danh mục, Tài khoản, Vị trí trang trại theo quyền thực tế.
- Giữ đúng màn khởi đầu theo vai trò đang có: STAFF tới vật nuôi, VET tới chăm sóc, ACCOUNTANT tới thu chi, ADMIN tới Tổng quan sau thiết lập. Không dùng index cứng khiến chuyển tab mở nhầm màn.
- Chuồng trại là lối vào chức năng chuồng có sẵn; Danh mục là loài/giống/khu vực. Chưa cần vẽ lại nội dung từng trang trong bước này.
- Giữ các route/callback đang được dùng, nút Back Android và trạng thái selected hợp lý khi vào màn con từ Thêm. Tránh AppBar trùng hai tầng.
- Desktop/Web vẫn có navigation thích hợp; không ép khung điện thoại trên màn rộng.
Hoàn thành khi mọi chức năng cũ còn truy cập được, menu tôn trọng vai trò, đổi tab/Back không mất luồng nhập hoặc mở sai page. Kiểm tra navigation và phân quyền bằng các test liên quan; chưa làm thay nội dung bước 04–16.

## Cách xử lý khi thấy chưa ổn
Áp dụng quy tắc dừng trong BRIEF.md: nếu cần đổi nghiệp vụ/API/quyền hoặc gặp vướng quan trọng, dừng phần đó và góp ý 4–6 dòng: Vướng / Ảnh hưởng / Đề xuất 1–2 cách. Hỏi một câu nếu cần quyết định. Các chi tiết UI nhỏ được tự xử lý; không hỏi xác nhận kế hoạch thông thường.

## Bàn giao
Bảo toàn thay đổi có sẵn; không hardcode số liệu mẫu vào app hoặc sửa backend cho giống ảnh. Kiểm tra đúng phạm vi, xem preview thật nếu có thể, cập nhật PROGRESS.md với bằng chứng và phần chưa xác minh. Trả lời tiếng Việt ngắn: kết quả, kiểm tra, ảnh thật, vướng mắc. Không tự commit/push/deploy.

