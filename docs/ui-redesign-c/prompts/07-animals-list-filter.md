# Prompt 07 — Danh sách và bộ lọc vật nuôi

Bạn đang làm trên dự án Flutter Smart Farm, đồ án cuối kỳ môn Phát triển ứng dụng di động đa nền tảng, repo https://github.com/BaoThien1805/Smart_Farm.
Workspace ban đầu: C:\Users\PC\Downloads\smart_farm. Nếu đang ở checkout khác của đúng repo, dùng root hiện tại; không tự clone lại.
Đây là chat mới: khôi phục bối cảnh bằng cách đọc docs/ui-redesign-c/BRIEF.md, PROGRESS.md cùng thư mục, AGENTS.md thực sự áp dụng và code hiện tại. Không giả định lịch sử chat trước.
Người dùng chọn phong cách C: nền kem, màu pastel, icon sticker bò/heo/dê cute, thông tin dễ đọc. Chỉ làm đúng bước 07; chưa tự làm bước kế tiếp.

Điều kiện trước bước: 01, 02, 03, 06 phải có kết quả phù hợp; kiểm tra cả code thật và PROGRESS.md. Nếu chưa đủ, báo ngắn và dừng phần phụ thuộc, không tự làm cả chuỗi.
Ảnh cần MỞ XEM: docs/ui-redesign-c/reference/nhom-03.png.
Điểm bắt đầu trong code: lib/features/farm/farm_pages.dart: AnimalsPage; lib/features/farm/farm_repository.dart; test/farm_test.dart; test/farm_identity_test.dart; test/api_response_test.dart.

## Công việc
Sửa màn 09 và 12: Đàn vật nuôi và bộ lọc.
- Dùng card/row có ảnh thật nếu có, fallback sticker theo loài, tên/mã, giống, chuồng và hai nhóm trạng thái rõ ràng: vòng đời và sức khỏe.
- Giữ tìm kiếm, debounce nếu có, phân trang, lọc loài/giống/chuồng/trạng thái và cơ chế load hiện tại. Không lọc giả trên một trang rồi coi là toàn đàn.
- Bộ lọc dùng bottom sheet hoặc full screen phù hợp chiều cao, có Áp dụng/Đặt lại và khôi phục lựa chọn trước đó.
- Chủ/nhân viên thấy nút thêm theo quyền; VET/kế toán tra cứu được nhưng không có nút sửa hoạt động trái phép.
- Khi tới từ card chuồng ở bước 06, nhận đúng penId thay vì lọc theo chuỗi tên.
Hoàn thành khi lọc/tìm/phân trang trả đúng kết quả, Back từ hồ sơ giữ trạng thái hợp lý và không có request lặp gây giật. Chạy các test list/filter/API hiện có, kiểm tra tên dài và danh sách rỗng.

## Cách xử lý khi thấy chưa ổn
Áp dụng quy tắc dừng trong BRIEF.md: nếu cần đổi nghiệp vụ/API/quyền hoặc gặp vướng quan trọng, dừng phần đó và góp ý 4–6 dòng: Vướng / Ảnh hưởng / Đề xuất 1–2 cách. Hỏi một câu nếu cần quyết định. Các chi tiết UI nhỏ được tự xử lý; không hỏi xác nhận kế hoạch thông thường.

## Bàn giao
Bảo toàn thay đổi có sẵn; không hardcode số liệu mẫu vào app hoặc sửa backend cho giống ảnh. Kiểm tra đúng phạm vi, xem preview thật nếu có thể, cập nhật PROGRESS.md với bằng chứng và phần chưa xác minh. Trả lời tiếng Việt ngắn: kết quả, kiểm tra, ảnh thật, vướng mắc. Không tự commit/push/deploy.

