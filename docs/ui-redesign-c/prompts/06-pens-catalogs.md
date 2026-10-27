# Prompt 06 — Chuồng trại và danh mục

Bạn đang làm trên dự án Flutter Smart Farm, đồ án cuối kỳ môn Phát triển ứng dụng di động đa nền tảng, repo https://github.com/BaoThien1805/Smart_Farm.
Workspace ban đầu: C:\Users\PC\Downloads\smart_farm. Nếu đang ở checkout khác của đúng repo, dùng root hiện tại; không tự clone lại.
Đây là chat mới: khôi phục bối cảnh bằng cách đọc docs/ui-redesign-c/BRIEF.md, PROGRESS.md cùng thư mục, AGENTS.md thực sự áp dụng và code hiện tại. Không giả định lịch sử chat trước.
Người dùng chọn phong cách C: nền kem, màu pastel, icon sticker bò/heo/dê cute, thông tin dễ đọc. Chỉ làm đúng bước 06; chưa tự làm bước kế tiếp.

Điều kiện trước bước: 01, 02, 03 phải có kết quả phù hợp; kiểm tra cả code thật và PROGRESS.md. Nếu chưa đủ, báo ngắn và dừng phần phụ thuộc, không tự làm cả chuỗi.
Ảnh cần MỞ XEM: docs/ui-redesign-c/reference/nhom-02.png.
Điểm bắt đầu trong code: lib/features/farm/farm_pages.dart: CatalogPage; lib/features/farm/farm_repository.dart; lib/features/farm/farm_widgets.dart; test/farm_test.dart; test/code_suggestion_test.dart.

## Công việc
Sửa màn 05–08: danh sách chuồng, loài/giống/khu vực và form thêm/sửa.
- Thẻ chuồng có tên/mã, số đang nuôi/sức chứa, progress bar và nhãn trạng thái chỉ khi có dữ liệu. Chạm mở danh sách vật nuôi đã lọc theo chuồng.
- Loài/giống/khu vực trình bày rõ quan hệ, có tìm/lọc và nút thêm/sửa/xóa đúng quyền đang có. Form giữ gợi ý mã, mã tùy chọn/bắt buộc theo code, sức chứa nguyên dương và trạng thái sử dụng.
- Icon loài của chuồng chỉ dùng khi suy ra từ dữ liệu đầy đủ; chuồng hỗn hợp hiển thị nhiều icon hoặc dùng icon chuồng. Không tải toàn bộ đàn hay gây nhiều request chỉ để trang trí.
- Ảnh 08 có thể có trường Ghi chú không thuộc model thực tế: không tự thêm trường/API mới. Những form chưa vẽ riêng áp dụng cùng bố cục.
- Giữ ràng buộc xóa danh mục có liên kết và quyền ADMIN; không hiển thị thao tác bị cấm chỉ để giống ảnh.
Hoàn thành khi mở chuồng -> xem đàn đúng bộ lọc, cập nhật danh mục và các lỗi phụ thuộc được xử lý như trước. Chạy test catalog/code/capacity liên quan.

## Cách xử lý khi thấy chưa ổn
Áp dụng quy tắc dừng trong BRIEF.md: nếu cần đổi nghiệp vụ/API/quyền hoặc gặp vướng quan trọng, dừng phần đó và góp ý 4–6 dòng: Vướng / Ảnh hưởng / Đề xuất 1–2 cách. Hỏi một câu nếu cần quyết định. Các chi tiết UI nhỏ được tự xử lý; không hỏi xác nhận kế hoạch thông thường.

## Bàn giao
Bảo toàn thay đổi có sẵn; không hardcode số liệu mẫu vào app hoặc sửa backend cho giống ảnh. Kiểm tra đúng phạm vi, xem preview thật nếu có thể, cập nhật PROGRESS.md với bằng chứng và phần chưa xác minh. Trả lời tiếng Việt ngắn: kết quả, kiểm tra, ảnh thật, vướng mắc. Không tự commit/push/deploy.

