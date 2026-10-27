# Prompt 13 — Thu chi, form và lịch sử chỉnh sửa

Bạn đang làm trên dự án Flutter Smart Farm, đồ án cuối kỳ môn Phát triển ứng dụng di động đa nền tảng, repo https://github.com/BaoThien1805/Smart_Farm.
Workspace ban đầu: C:\Users\PC\Downloads\smart_farm. Nếu đang ở checkout khác của đúng repo, dùng root hiện tại; không tự clone lại.
Đây là chat mới: khôi phục bối cảnh bằng cách đọc docs/ui-redesign-c/BRIEF.md, PROGRESS.md cùng thư mục, AGENTS.md thực sự áp dụng và code hiện tại. Không giả định lịch sử chat trước.
Người dùng chọn phong cách C: nền kem, màu pastel, icon sticker bò/heo/dê cute, thông tin dễ đọc. Chỉ làm đúng bước 13; chưa tự làm bước kế tiếp.

Điều kiện trước bước: 01, 02, 03 phải có kết quả phù hợp; kiểm tra cả code thật và PROGRESS.md. Nếu chưa đủ, báo ngắn và dừng phần phụ thuộc, không tự làm cả chuỗi.
Ảnh cần MỞ XEM: docs/ui-redesign-c/reference/nhom-07.png; docs/ui-redesign-c/reference/nhom-10.png.
Điểm bắt đầu trong code: lib/features/farm/finance_page.dart; lib/features/farm/farm_widgets.dart; test/phase_5_test.dart; test/roles_test.dart.

## Công việc
Sửa màn 27, 28 và 39: sổ thu chi, ghi/sửa/hủy thủ công, audit.
- Thẻ Tổng thu/Tổng chi/Chênh lệch rõ đơn vị VND; ledger có ngày, nội dung, danh mục, người thực hiện và trạng thái đúng dữ liệu thật.
- Chỉ ADMIN/ACCOUNTANT truy cập thao tác tài chính theo quyền. Giữ bộ lọc kỳ và phân trang đang có.
- Giữ loại tiền nguyên VND, danh mục hợp lệ và validation hiện có. ANIMAL_SALE dành cho giao dịch bán liên kết, không đưa vào chọn thủ công.
- Audit hiển thị thao tác, trước/sau, người thực hiện, lý do và thời điểm từ API; không tự thêm nhà cung cấp/đơn giá/số lượng kiểu hóa đơn.
- Hủy phải có lý do, giữ dữ liệu lịch sử và khác với xóa bản ghi. Không cho sửa/hủy phiếu liên kết bán qua luồng thủ công nếu đang bị cấm.
Hoàn thành khi totals/currency và các trạng thái được giữ đúng, sửa/hủy làm refresh nhất quán. Chạy test finance UI/roles đang có; chưa thay phần biểu đồ và bán của bước 14.

## Cách xử lý khi thấy chưa ổn
Áp dụng quy tắc dừng trong BRIEF.md: nếu cần đổi nghiệp vụ/API/quyền hoặc gặp vướng quan trọng, dừng phần đó và góp ý 4–6 dòng: Vướng / Ảnh hưởng / Đề xuất 1–2 cách. Hỏi một câu nếu cần quyết định. Các chi tiết UI nhỏ được tự xử lý; không hỏi xác nhận kế hoạch thông thường.

## Bàn giao
Bảo toàn thay đổi có sẵn; không hardcode số liệu mẫu vào app hoặc sửa backend cho giống ảnh. Kiểm tra đúng phạm vi, xem preview thật nếu có thể, cập nhật PROGRESS.md với bằng chứng và phần chưa xác minh. Trả lời tiếng Việt ngắn: kết quả, kiểm tra, ảnh thật, vướng mắc. Không tự commit/push/deploy.

