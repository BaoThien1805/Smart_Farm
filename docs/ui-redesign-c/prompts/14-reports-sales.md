# Prompt 14 — Biểu đồ, giao dịch bán và hủy bán

Bạn đang làm trên dự án Flutter Smart Farm, đồ án cuối kỳ môn Phát triển ứng dụng di động đa nền tảng, repo https://github.com/BaoThien1805/Smart_Farm.
Workspace ban đầu: C:\Users\PC\Downloads\smart_farm. Nếu đang ở checkout khác của đúng repo, dùng root hiện tại; không tự clone lại.
Đây là chat mới: khôi phục bối cảnh bằng cách đọc docs/ui-redesign-c/BRIEF.md, PROGRESS.md cùng thư mục, AGENTS.md thực sự áp dụng và code hiện tại. Không giả định lịch sử chat trước.
Người dùng chọn phong cách C: nền kem, màu pastel, icon sticker bò/heo/dê cute, thông tin dễ đọc. Chỉ làm đúng bước 14; chưa tự làm bước kế tiếp.

Điều kiện trước bước: 01, 02, 08, 13 phải có kết quả phù hợp; kiểm tra cả code thật và PROGRESS.md. Nếu chưa đủ, báo ngắn và dừng phần phụ thuộc, không tự làm cả chuỗi.
Ảnh cần MỞ XEM: docs/ui-redesign-c/reference/nhom-08.png.
Điểm bắt đầu trong code: lib/features/farm/revenue_chart.dart; lib/features/farm/finance_page.dart; lib/features/farm/dashboard_page.dart; test/revenue_chart_test.dart; test/phase_5_test.dart.

## Công việc
Sửa màn 29–32: báo cáo theo kỳ, danh sách bán, form bán và hủy bán.
- Dùng biểu đồ/bảng hoặc card tháng hiện có với màu C, số liệu thật, tháng không phát sinh và tiền dài vẫn đọc được trên mobile.
- Giữ đủ các series Doanh thu bán/Tổng thu/Tổng chi và bảng số liệu chính xác. Doanh thu bán là một phần Tổng thu; chênh lệch thu chi không đổi tên thành lợi nhuận.
- Chỉ ADMIN bán/hủy bán; ACCOUNTANT có quyền sổ thủ công/báo cáo nhưng không được bán. Vật nuôi phải ở trạng thái cho phép.
- Form bán giữ ngày/tiền/người mua/ghi chú, phiếu thu liên kết hiện có. Form hủy giữ chuồng nhận lại đủ chỗ, ngày và lý do.
- Không thêm nút thanh toán ngân hàng, xuất báo cáo hay chức năng ngoài scope.
Hoàn thành khi chart/table khớp API, luồng bán/hủy và refresh trạng thái không bị thay đổi nghiệp vụ. Chạy test chart/finance/roles liên quan, đối chiếu các tổng và trường hợp phiếu đã hủy.

## Cách xử lý khi thấy chưa ổn
Áp dụng quy tắc dừng trong BRIEF.md: nếu cần đổi nghiệp vụ/API/quyền hoặc gặp vướng quan trọng, dừng phần đó và góp ý 4–6 dòng: Vướng / Ảnh hưởng / Đề xuất 1–2 cách. Hỏi một câu nếu cần quyết định. Các chi tiết UI nhỏ được tự xử lý; không hỏi xác nhận kế hoạch thông thường.

## Bàn giao
Bảo toàn thay đổi có sẵn; không hardcode số liệu mẫu vào app hoặc sửa backend cho giống ảnh. Kiểm tra đúng phạm vi, xem preview thật nếu có thể, cập nhật PROGRESS.md với bằng chứng và phần chưa xác minh. Trả lời tiếng Việt ngắn: kết quả, kiểm tra, ảnh thật, vướng mắc. Không tự commit/push/deploy.

