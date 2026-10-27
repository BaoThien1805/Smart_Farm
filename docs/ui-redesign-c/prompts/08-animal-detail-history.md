# Prompt 08 — Hồ sơ, ảnh và lịch sử vật nuôi

Bạn đang làm trên dự án Flutter Smart Farm, đồ án cuối kỳ môn Phát triển ứng dụng di động đa nền tảng, repo https://github.com/BaoThien1805/Smart_Farm.
Workspace ban đầu: C:\Users\PC\Downloads\smart_farm. Nếu đang ở checkout khác của đúng repo, dùng root hiện tại; không tự clone lại.
Đây là chat mới: khôi phục bối cảnh bằng cách đọc docs/ui-redesign-c/BRIEF.md, PROGRESS.md cùng thư mục, AGENTS.md thực sự áp dụng và code hiện tại. Không giả định lịch sử chat trước.
Người dùng chọn phong cách C: nền kem, màu pastel, icon sticker bò/heo/dê cute, thông tin dễ đọc. Chỉ làm đúng bước 08; chưa tự làm bước kế tiếp.

Điều kiện trước bước: 01, 02, 03, 07 phải có kết quả phù hợp; kiểm tra cả code thật và PROGRESS.md. Nếu chưa đủ, báo ngắn và dừng phần phụ thuộc, không tự làm cả chuỗi.
Ảnh cần MỞ XEM: docs/ui-redesign-c/reference/nhom-03.png; docs/ui-redesign-c/reference/nhom-05.png.
Điểm bắt đầu trong code: lib/features/farm/farm_pages.dart: AnimalDetailPage; lib/core/photo_view.dart; lib/core/photo_picker.dart; test/photo_workflow_test.dart; test/roles_test.dart.

## Công việc
Sửa màn 10 và 20: Hồ sơ cá thể và lịch sử.
- Header có ảnh, mã/tên, giống, giới tính, chuồng, vòng đời và tình trạng sức khỏe từ dữ liệu thật.
- Tổ chức Thông tin/Cân nặng/Sức khỏe/Lịch sử hoặc tương đương, tránh lặp thông tin dài; không làm mất dữ liệu và thao tác hiện có.
- Timeline dùng các bản ghi thật: cân, chuyển chuồng, sức khỏe, chăm sóc và bán nếu API trả về; hiển thị ngày/người thực hiện, không tự suy đoán sự kiện.
- Ưu tiên ảnh tải lên. Nút ảnh dùng luồng chọn ảnh hiện có; biểu tượng camera trong mockup không đồng nghĩa đã có chức năng mở camera.
- Các CTA Ghi cân/Chuyển chuồng/Ghi sức khỏe/Khám/Bán/Ghi chết/Xóa hiển thị theo quyền và vòng đời. Trong bước này chỉ đổi cách bố trí, giữ callback/form cũ nếu bước 10 chưa làm.
Hoàn thành khi mọi tab và action hợp lệ còn dùng được; không show nút trái quyền, không mất ảnh/lịch sử khi refresh. Chạy test profile/photo/roles liên quan và đối chiếu preview thật.

## Cách xử lý khi thấy chưa ổn
Áp dụng quy tắc dừng trong BRIEF.md: nếu cần đổi nghiệp vụ/API/quyền hoặc gặp vướng quan trọng, dừng phần đó và góp ý 4–6 dòng: Vướng / Ảnh hưởng / Đề xuất 1–2 cách. Hỏi một câu nếu cần quyết định. Các chi tiết UI nhỏ được tự xử lý; không hỏi xác nhận kế hoạch thông thường.

## Bàn giao
Bảo toàn thay đổi có sẵn; không hardcode số liệu mẫu vào app hoặc sửa backend cho giống ảnh. Kiểm tra đúng phạm vi, xem preview thật nếu có thể, cập nhật PROGRESS.md với bằng chứng và phần chưa xác minh. Trả lời tiếng Việt ngắn: kết quả, kiểm tra, ảnh thật, vướng mắc. Không tự commit/push/deploy.

