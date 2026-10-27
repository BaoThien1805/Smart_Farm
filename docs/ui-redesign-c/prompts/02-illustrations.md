# Prompt 02 — Bộ icon vật nuôi và hình minh họa

Bạn đang làm trên dự án Flutter Smart Farm, đồ án cuối kỳ môn Phát triển ứng dụng di động đa nền tảng, repo https://github.com/BaoThien1805/Smart_Farm.
Workspace ban đầu: C:\Users\PC\Downloads\smart_farm. Nếu đang ở checkout khác của đúng repo, dùng root hiện tại; không tự clone lại.
Đây là chat mới: khôi phục bối cảnh bằng cách đọc docs/ui-redesign-c/BRIEF.md, PROGRESS.md cùng thư mục, AGENTS.md thực sự áp dụng và code hiện tại. Không giả định lịch sử chat trước.
Người dùng chọn phong cách C: nền kem, màu pastel, icon sticker bò/heo/dê cute, thông tin dễ đọc. Chỉ làm đúng bước 02; chưa tự làm bước kế tiếp.

Điều kiện trước bước: 01 phải có kết quả phù hợp; kiểm tra cả code thật và PROGRESS.md. Nếu chưa đủ, báo ngắn và dừng phần phụ thuộc, không tự làm cả chuỗi.
Ảnh cần MỞ XEM: docs/ui-redesign-c/reference/nhom-01.png; docs/ui-redesign-c/reference/nhom-02.png; docs/ui-redesign-c/reference/nhom-03.png; docs/ui-redesign-c/reference/nhom-06.png; docs/ui-redesign-c/reference/nhom-11.png.
Điểm bắt đầu trong code: pubspec.yaml; lib/core/; assets/.

## Công việc
Tạo asset thực cho phong cách sticker C và widget dùng lại, chưa sửa toàn bộ page.
- Đọc skill imagegen khi dùng công cụ tạo ảnh. Tạo bộ bò, heo, dê, gà cùng nét viền, cùng tỉ lệ, rõ ở 48–96px; ưu tiên PNG nền trong suốt. Tạo một banner nông trại dùng cho màn chào/Tổng quan, tách khỏi nội dung và nút bấm.
- Lưu asset cuối trong assets/ của dự án, khai báo pubspec.yaml và dùng Image.asset hoặc cơ chế tương đương. Không lấy nguyên ảnh mockup làm nền giao diện, không cắt cả thẻ có chữ thành một asset.
- Tạo widget chọn minh họa từ loài thật và có fallback trung tính khi chưa nhận biết loài. Với ảnh vật nuôi đã được người dùng tải lên, luôn ưu tiên ảnh đó; sticker chỉ là fallback hoặc trang trí.
- Không gán bò/heo cho chuồng theo mã A1/B1. Chuồng có thể hỗn hợp loài; chưa có dữ liệu thì dùng icon chuồng.
- Chú ý asset thiếu, semantics và kích thước file. Không thay bằng emoji tùy nền tảng rồi coi là đã khớp mẫu.
Nếu không có công cụ/tài nguyên phù hợp để tạo asset đúng phong cách, dừng phần asset và góp ý ngắn về phương án thay thế; chưa tự chốt phong cách khác.
Hoàn thành khi asset đã đóng gói trong repo, render được qua một preview nhỏ và có hướng dẫn dùng ngắn trong PROGRESS.md.

## Cách xử lý khi thấy chưa ổn
Áp dụng quy tắc dừng trong BRIEF.md: nếu cần đổi nghiệp vụ/API/quyền hoặc gặp vướng quan trọng, dừng phần đó và góp ý 4–6 dòng: Vướng / Ảnh hưởng / Đề xuất 1–2 cách. Hỏi một câu nếu cần quyết định. Các chi tiết UI nhỏ được tự xử lý; không hỏi xác nhận kế hoạch thông thường.

## Bàn giao
Bảo toàn thay đổi có sẵn; không hardcode số liệu mẫu vào app hoặc sửa backend cho giống ảnh. Kiểm tra đúng phạm vi, xem preview thật nếu có thể, cập nhật PROGRESS.md với bằng chứng và phần chưa xác minh. Trả lời tiếng Việt ngắn: kết quả, kiểm tra, ảnh thật, vướng mắc. Không tự commit/push/deploy.

