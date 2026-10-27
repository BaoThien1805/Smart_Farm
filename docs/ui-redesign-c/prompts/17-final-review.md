# Prompt 17 — Trạng thái chung và rà soát toàn bộ

Bạn đang làm trên dự án Flutter Smart Farm, đồ án cuối kỳ môn Phát triển ứng dụng di động đa nền tảng, repo https://github.com/BaoThien1805/Smart_Farm.
Workspace ban đầu: C:\Users\PC\Downloads\smart_farm. Nếu đang ở checkout khác của đúng repo, dùng root hiện tại; không tự clone lại.
Đây là chat mới: khôi phục bối cảnh bằng cách đọc docs/ui-redesign-c/BRIEF.md, PROGRESS.md cùng thư mục, AGENTS.md thực sự áp dụng và code hiện tại. Không giả định lịch sử chat trước.
Người dùng chọn phong cách C: nền kem, màu pastel, icon sticker bò/heo/dê cute, thông tin dễ đọc. Chỉ làm đúng bước 17; chưa tự làm bước kế tiếp.

Điều kiện trước bước: 04, 05, 06, 07, 08, 09, 10, 11, 12, 13, 14, 15, 16 phải có kết quả phù hợp; kiểm tra cả code thật và PROGRESS.md. Nếu chưa đủ, báo ngắn và dừng phần phụ thuộc, không tự làm cả chuỗi.
Ảnh cần MỞ XEM: docs/ui-redesign-c/reference/nhom-01.png; docs/ui-redesign-c/reference/nhom-02.png; docs/ui-redesign-c/reference/nhom-03.png; docs/ui-redesign-c/reference/nhom-04.png; docs/ui-redesign-c/reference/nhom-05.png; docs/ui-redesign-c/reference/nhom-06.png; docs/ui-redesign-c/reference/nhom-07.png; docs/ui-redesign-c/reference/nhom-08.png; docs/ui-redesign-c/reference/nhom-09.png; docs/ui-redesign-c/reference/nhom-10.png; docs/ui-redesign-c/reference/nhom-11.png.
Điểm bắt đầu trong code: lib/core/theme.dart; lib/features/farm/farm_widgets.dart; lib/features/; test/; pubspec.yaml.

## Công việc
Rà soát tích hợp, không làm lại app hoặc tự mở scope tính năng.
- Hoàn thiện màn 41–42: empty, loading, retry, validation, busy và feedback thống nhất. Lỗi thời tiết là lỗi cục bộ; lỗi mạng không tự chuyển sang đồng bộ offline.
- So lại từng nhóm 01–44 với implementation thật; kiểm tra menu, Back, bàn phím, form dài, ảnh thật/fallback, nhiều loài, chuồng hỗn hợp và người dùng bốn vai trò.
- Sửa các lỗi responsive, overflow, mất thao tác, spacing và màu không thống nhất do các bước trước. Không thay nghiệp vụ hoặc xóa test để đạt kết quả.
- Chạy flutter analyze và toàn bộ flutter test một lần sau khi sửa xong; build web và build APK debug/release phù hợp cấu hình hiện có nếu toolchain sẵn sàng. Không tự chấp nhận giấy phép, sửa signing hay thay SDK toàn máy để ép build.
- Nếu có thiết bị local sẵn, kiểm tra Android và lấy screenshot thực. Dùng tài khoản/dữ liệu local hoặc fixture kiểm thử cho thao tác ghi; không dùng production để tạo demo. Không khẳng định Android đã đạt chỉ vì web build thành công.
- Lập checklist nghiệm thu 44 view (có thể dùng cùng form), bằng chứng kiểm tra và các hạn chế còn lại trong PROGRESS.md; ảnh thật lưu outputs/ui-redesign-c/.
Hoàn thành khi không còn regression do lần sửa UI, có bản chụp thực để người dùng duyệt, và báo rõ các kiểm tra bị môi trường chặn. Không tự commit/push/deploy hay chuyển sang tính năng mới.

## Cách xử lý khi thấy chưa ổn
Áp dụng quy tắc dừng trong BRIEF.md: nếu cần đổi nghiệp vụ/API/quyền hoặc gặp vướng quan trọng, dừng phần đó và góp ý 4–6 dòng: Vướng / Ảnh hưởng / Đề xuất 1–2 cách. Hỏi một câu nếu cần quyết định. Các chi tiết UI nhỏ được tự xử lý; không hỏi xác nhận kế hoạch thông thường.

## Bàn giao
Bảo toàn thay đổi có sẵn; không hardcode số liệu mẫu vào app hoặc sửa backend cho giống ảnh. Kiểm tra đúng phạm vi, xem preview thật nếu có thể, cập nhật PROGRESS.md với bằng chứng và phần chưa xác minh. Trả lời tiếng Việt ngắn: kết quả, kiểm tra, ảnh thật, vướng mắc. Không tự commit/push/deploy.

