# Prompt 00 — Khảo sát và chốt phạm vi kỹ thuật

Bạn đang làm trên dự án Flutter Smart Farm, đồ án cuối kỳ môn Phát triển ứng dụng di động đa nền tảng, repo https://github.com/BaoThien1805/Smart_Farm.
Workspace ban đầu: C:\Users\PC\Downloads\smart_farm. Nếu đang ở checkout khác của đúng repo, dùng root hiện tại; không tự clone lại.
Đây là chat mới: khôi phục bối cảnh bằng cách đọc docs/ui-redesign-c/BRIEF.md, PROGRESS.md cùng thư mục, AGENTS.md thực sự áp dụng và code hiện tại. Không giả định lịch sử chat trước.
Người dùng chọn phong cách C: nền kem, màu pastel, icon sticker bò/heo/dê cute, thông tin dễ đọc. Chỉ làm đúng bước 00; chưa tự làm bước kế tiếp.

Điều kiện trước bước: Không có. Đây là bước khảo sát đầu tiên.
Ảnh cần MỞ XEM: docs/ui-redesign-c/reference/nhom-01.png; docs/ui-redesign-c/reference/nhom-02.png; docs/ui-redesign-c/reference/nhom-03.png; docs/ui-redesign-c/reference/nhom-04.png; docs/ui-redesign-c/reference/nhom-05.png; docs/ui-redesign-c/reference/nhom-06.png; docs/ui-redesign-c/reference/nhom-07.png; docs/ui-redesign-c/reference/nhom-08.png; docs/ui-redesign-c/reference/nhom-09.png; docs/ui-redesign-c/reference/nhom-10.png; docs/ui-redesign-c/reference/nhom-11.png.
Điểm bắt đầu trong code: lib/core/theme.dart; lib/features/home/workspace_page.dart; lib/features/farm/farm_widgets.dart; pubspec.yaml; test/.

## Công việc
Chỉ khảo sát, chưa sửa giao diện ứng dụng.
- Đọc cấu trúc Flutter, các luồng chính, mô hình quyền, cách lấy dữ liệu, form dùng chung và asset hiện có. Kiểm tra trạng thái Git; ghi nhận thay đổi có sẵn để tránh đụng vào.
- Mở các ảnh tham chiếu để hiểu phong cách và đối chiếu 44 view với các page/dialog thực tế. Lập danh sách màn có sẵn, màn chỉ là cách trình bày mới và chi tiết trong ảnh chưa có dữ liệu hỗ trợ.
- Chỉ ra tối đa 5 vấn đề có ảnh hưởng thực tế: ví dụ icon loài của chuồng hỗn hợp, ảnh cá thể so với sticker, lịch chỉ có ngày, dữ liệu thời tiết chưa cấu hình.
- Xác định cách chạy kiểm thử/preview local. Chạy flutter analyze và bộ flutter test hiện có để ghi baseline nếu môi trường cho phép; không cam kết số lượng cố định.
- Ghi kết quả khảo sát vào PROGRESS.md: cấu trúc file hiện tại, baseline, tài nguyên còn thiếu, hướng triển khai ngắn gọn và thông tin cần người dùng quyết định. Không sửa backend, cài lại SDK hay tự chấp nhận giấy phép.
Hoàn thành khi có bản khảo sát đủ để bắt đầu bước 01. Nếu không có trở ngại lớn, nói rõ có thể bắt đầu; không tự thực hiện bước 01.

## Cách xử lý khi thấy chưa ổn
Áp dụng quy tắc dừng trong BRIEF.md: nếu cần đổi nghiệp vụ/API/quyền hoặc gặp vướng quan trọng, dừng phần đó và góp ý 4–6 dòng: Vướng / Ảnh hưởng / Đề xuất 1–2 cách. Hỏi một câu nếu cần quyết định. Các chi tiết UI nhỏ được tự xử lý; không hỏi xác nhận kế hoạch thông thường.

## Bàn giao
Bảo toàn thay đổi có sẵn; không hardcode số liệu mẫu vào app hoặc sửa backend cho giống ảnh. Kiểm tra đúng phạm vi, xem preview thật nếu có thể, cập nhật PROGRESS.md với bằng chứng và phần chưa xác minh. Trả lời tiếng Việt ngắn: kết quả, kiểm tra, ảnh thật, vướng mắc. Không tự commit/push/deploy.

