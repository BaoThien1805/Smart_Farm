# Prompt 01 — Bộ màu và thành phần dùng chung

Bạn đang làm trên dự án Flutter Smart Farm, đồ án cuối kỳ môn Phát triển ứng dụng di động đa nền tảng, repo https://github.com/BaoThien1805/Smart_Farm.
Workspace ban đầu: C:\Users\PC\Downloads\smart_farm. Nếu đang ở checkout khác của đúng repo, dùng root hiện tại; không tự clone lại.
Đây là chat mới: khôi phục bối cảnh bằng cách đọc docs/ui-redesign-c/BRIEF.md, PROGRESS.md cùng thư mục, AGENTS.md thực sự áp dụng và code hiện tại. Không giả định lịch sử chat trước.
Người dùng chọn phong cách C: nền kem, màu pastel, icon sticker bò/heo/dê cute, thông tin dễ đọc. Chỉ làm đúng bước 01; chưa tự làm bước kế tiếp.

Điều kiện trước bước: 00 phải có kết quả phù hợp; kiểm tra cả code thật và PROGRESS.md. Nếu chưa đủ, báo ngắn và dừng phần phụ thuộc, không tự làm cả chuỗi.
Ảnh cần MỞ XEM: docs/ui-redesign-c/reference/nhom-01.png; docs/ui-redesign-c/reference/nhom-02.png; docs/ui-redesign-c/reference/nhom-03.png; docs/ui-redesign-c/reference/nhom-06.png.
Điểm bắt đầu trong code: lib/core/theme.dart; lib/features/farm/farm_widgets.dart; lib/core/suggested_code_field.dart.

## Công việc
Triển khai nền giao diện C: nền kem, chữ nâu đậm, xanh teal chủ đạo, thẻ trắng bo góc, pastel mint/đào/tím/xanh nhạt.
- Chuẩn hóa token màu, khoảng cách, radius, typography, nút, ô nhập, chip trạng thái, card, dialog và thanh điều hướng. Giữ tương thích các hằng/theme API mà màn khác đang dùng.
- Tạo một số widget chung thật sự cần dùng lại: thẻ thông tin, badge trạng thái có text, tiêu đề nhóm, khung nhập liệu, bố cục form. Không tạo framework UI tổng quát lớn.
- Với farmForm, cân nhắc cùng nội dung form hiển thị full screen trên điện thoại và dialog có giới hạn chiều rộng trên desktop. Giữ nguyên validation, controllers, callbacks, trạng thái busy/error và giá trị trả về; tránh đổi signature nếu không cần.
- Dùng font hỗ trợ tiếng Việt có sẵn hoặc đóng gói local; không phụ thuộc tải font qua mạng lúc chạy.
- Chưa chuyển navigation, chưa bố trí lại các màn chức năng, chưa tạo asset hình.
Hoàn thành khi các màn cũ vẫn hoạt động với theme mới, phần nhập liệu không bị bàn phím che và không có lỗi layout ở màn nhỏ. Chạy analyze và các kiểm thử form/layout liên quan. Chỉ bổ sung test khi có thay đổi hành vi bố cục cần bảo vệ.

## Cách xử lý khi thấy chưa ổn
Áp dụng quy tắc dừng trong BRIEF.md: nếu cần đổi nghiệp vụ/API/quyền hoặc gặp vướng quan trọng, dừng phần đó và góp ý 4–6 dòng: Vướng / Ảnh hưởng / Đề xuất 1–2 cách. Hỏi một câu nếu cần quyết định. Các chi tiết UI nhỏ được tự xử lý; không hỏi xác nhận kế hoạch thông thường.

## Bàn giao
Bảo toàn thay đổi có sẵn; không hardcode số liệu mẫu vào app hoặc sửa backend cho giống ảnh. Kiểm tra đúng phạm vi, xem preview thật nếu có thể, cập nhật PROGRESS.md với bằng chứng và phần chưa xác minh. Trả lời tiếng Việt ngắn: kết quả, kiểm tra, ảnh thật, vướng mắc. Không tự commit/push/deploy.

