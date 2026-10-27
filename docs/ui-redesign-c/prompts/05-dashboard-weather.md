# Prompt 05 — Tổng quan, thời tiết và vị trí trại

Bạn đang làm trên dự án Flutter Smart Farm, đồ án cuối kỳ môn Phát triển ứng dụng di động đa nền tảng, repo https://github.com/BaoThien1805/Smart_Farm.
Workspace ban đầu: C:\Users\PC\Downloads\smart_farm. Nếu đang ở checkout khác của đúng repo, dùng root hiện tại; không tự clone lại.
Đây là chat mới: khôi phục bối cảnh bằng cách đọc docs/ui-redesign-c/BRIEF.md, PROGRESS.md cùng thư mục, AGENTS.md thực sự áp dụng và code hiện tại. Không giả định lịch sử chat trước.
Người dùng chọn phong cách C: nền kem, màu pastel, icon sticker bò/heo/dê cute, thông tin dễ đọc. Chỉ làm đúng bước 05; chưa tự làm bước kế tiếp.

Điều kiện trước bước: 01, 02, 03 phải có kết quả phù hợp; kiểm tra cả code thật và PROGRESS.md. Nếu chưa đủ, báo ngắn và dừng phần phụ thuộc, không tự làm cả chuỗi.
Ảnh cần MỞ XEM: docs/ui-redesign-c/reference/nhom-01.png; docs/ui-redesign-c/reference/nhom-10.png.
Điểm bắt đầu trong code: lib/features/farm/dashboard_page.dart; lib/features/farm/weather_card.dart; lib/core/device_location.dart; test/dashboard_test.dart; test/weather_card_test.dart; test/device_location_test.dart.

## Công việc
Sửa màn 04 và 38 theo C.
- Tổng quan có header nông trại nhỏ, thẻ số liệu, việc cần làm, cảnh báo và lối vào các chức năng. Tận dụng API/dashboard hiện có; không hardcode 36 vật nuôi, 6 chuồng, tên trại hay cảnh báo mẫu.
- Các khối tài chính chỉ xuất hiện với người có quyền. Giữ báo cáo/biểu đồ hiện có, không làm mất chức năng vì ảnh concept không thể hiện hết.
- Thời tiết hiển thị dữ liệu thật, trạng thái tải/thiếu key/lỗi riêng, không biến mất toàn bộ Tổng quan khi dịch vụ thời tiết lỗi.
- Vị trí trại giữ chức năng lấy GPS, nhập vĩ độ/kinh độ, lưu/xóa nếu đang có và xử lý quyền vị trí. Không tự thêm bản đồ, geocoding hay địa chỉ dạng chữ chưa được API hỗ trợ.
- Chỉ hiển thị chi tiết chuồng khi có dữ liệu phù hợp; nếu API không có một khối, dùng lối vào chức năng hiện có hoặc đề xuất gọn thay vì fake dữ liệu.
Hoàn thành khi mỗi thẻ/CTA mở đúng màn, dữ liệu live đúng quyền và layout không tràn. Chạy test dashboard/weather/location, báo rõ phần chưa kiểm tra được trên thiết bị thật.

## Cách xử lý khi thấy chưa ổn
Áp dụng quy tắc dừng trong BRIEF.md: nếu cần đổi nghiệp vụ/API/quyền hoặc gặp vướng quan trọng, dừng phần đó và góp ý 4–6 dòng: Vướng / Ảnh hưởng / Đề xuất 1–2 cách. Hỏi một câu nếu cần quyết định. Các chi tiết UI nhỏ được tự xử lý; không hỏi xác nhận kế hoạch thông thường.

## Bàn giao
Bảo toàn thay đổi có sẵn; không hardcode số liệu mẫu vào app hoặc sửa backend cho giống ảnh. Kiểm tra đúng phạm vi, xem preview thật nếu có thể, cập nhật PROGRESS.md với bằng chứng và phần chưa xác minh. Trả lời tiếng Việt ngắn: kết quả, kiểm tra, ảnh thật, vướng mắc. Không tự commit/push/deploy.

