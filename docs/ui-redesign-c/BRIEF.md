# Smart Farm — Bối cảnh triển khai giao diện C

## Mục tiêu đã được người dùng đồng ý

Đây là đồ án cuối kỳ môn Phát triển ứng dụng di động đa nền tảng. Người dùng muốn làm giao diện Flutter dễ nhìn, gần gũi và có bò/heo/dê cute theo phương án C đã duyệt về hướng thiết kế. Lần giao việc này chia nhỏ theo prompt, chưa có yêu cầu triển khai toàn bộ trong một lần.

Repo gốc: https://github.com/BaoThien1805/Smart_Farm
Workspace ban đầu: C:\Users\PC\Downloads\smart_farm
Tài liệu này ở docs/ui-redesign-c/BRIEF.md, ảnh ở docs/ui-redesign-c/reference/.
Tất cả ảnh trong bộ này là concept, không phải screenshot chứng minh implementation đã tồn tại.

## Nguồn cần đọc trong một chat mới

1. Đọc AGENTS.md nào thực sự áp dụng, nếu có; không tự tạo hoặc thay AGENTS.md toàn repo cho nhiệm vụ này.
2. Đọc BRIEF.md này, PROGRESS.md và đúng file prompt được người dùng giao.
3. Mở xem ảnh PNG tương ứng; xem index.html để định vị nhóm nếu cần. Không chỉ đọc tên ảnh hoặc prompt sinh ảnh rồi coi là đã xem.
4. Đọc code hiện tại ở các file liên quan. Những đường dẫn trong prompt là điểm bắt đầu, không phải yêu cầu giữ nguyên cấu trúc đã lỗi thời.
5. Kiểm tra Git và thay đổi có sẵn. Không tự restore/clean/reset/stash hay ghi đè công việc của người khác. Bộ prompt được soạn khi có thay đổi ở các plugin registrant do Flutter sinh; không coi đó là phần được phép tự xóa.

Không cần và không được giả định mình biết lịch sử chat trước. Mỗi bước dùng chính tài liệu, ảnh và code để khôi phục bối cảnh.

## Quy tắc thực hiện và dừng để góp ý

- Mỗi lượt thực hiện đúng một bước được giao. Nếu đủ điều kiện, triển khai trực tiếp tới kết quả kiểm tra được; không dừng ở kế hoạch rồi hỏi có làm tiếp không.
- Đọc tiến độ và kiểm tra code thật để xác nhận điều kiện tiên quyết. Nếu phần nền chưa có, báo ngắn bước cần làm trước; không tự làm tất cả các bước trước đó.
- Có thể điều chỉnh padding, responsive, tên widget và cách chia component bằng phán đoán kỹ thuật; không hỏi người dùng cho từng chi tiết nhỏ.
- Dừng phần liên quan khi phát hiện mâu thuẫn quan trọng với nghiệp vụ/quyền/dữ liệu; cần thêm API hoặc thay schema; thiếu tài nguyên không thể thay hợp lý; cần phụ thuộc/dịch vụ mới làm tăng scope đáng kể; hoặc thay đổi đang có khiến không thể sửa an toàn.
- Khi dừng, giải thích tối đa 4–6 dòng, theo mẫu:
  "Vướng: [vấn đề cụ thể]."
  "Ảnh hưởng: [điều người dùng sẽ thấy hoặc rủi ro thực tế]."
  "Đề xuất: [1–2 phương án, nêu phương án nên chọn]."
  Chỉ hỏi một câu nếu cần người dùng quyết định. Không âm thầm bỏ chức năng, fake dữ liệu hoặc đổi nghiệp vụ cho giống ảnh.
- Phần độc lập vẫn làm được thì tiếp tục; ghi rõ phần chưa làm. Không đánh dấu bước Hoàn tất khi còn việc bắt buộc.
- Không tự commit, push, deploy hoặc chuyển sang bước kế tiếp. Không tự tạo task/chat, automation hay gọi agent khác; bộ công việc này dùng tuần tự để tránh sửa chung file.
- Nếu vấn đề là thiếu SDK/device/toolchain, báo chính xác giới hạn kiểm tra, không tự tải lại cả môi trường hoặc tự đồng ý giấy phép.

## Phạm vi thay đổi

Mặc định sửa Flutter UI, asset đóng gói local và test liên quan. Giữ API contract, schema DB, session/token, validation, requestId/idempotency và quy tắc phân quyền hiện có.

Không bổ sung AI, QR, bản đồ game, thông báo đẩy, đồng bộ offline, thanh toán, xuất báo cáo hay tính năng mới chỉ vì ảnh có yếu tố trang trí. Nếu có ý tưởng ngoài scope, ghi một câu đề xuất cuối lượt.

Có thể tách widget trong file lớn khi cần cho phần đang sửa; không tranh thủ đổi toàn bộ kiến trúc state management, routing, repository hoặc backend.

## Phong cách C

- Nền kem ấm, chữ cocoa đậm; teal/forest green là màu hành động chính.
- Mint, đào, lavender và sky-blue dùng làm điểm nhấn theo nhóm nội dung.
- Thẻ trắng/kem, viền nhẹ, radius khoảng 16–24, bóng rất nhẹ.
- Sticker vật nuôi nét viền nhất quán. Ưu tiên sự rõ ràng của dữ liệu và thao tác.
- Palette xuất phát gợi ý: nền #FFF9F0, chữ #3A261C, primary #187360, mint #DDF2E7, peach #FFE5D2, lavender #EAE0FF, sky #E1F2FF, amber #FFF0C7. Có thể chỉnh để đạt tương phản và khớp ảnh tốt hơn.
- Body khoảng 14–16sp; heading thường 22–28sp tùy viewport. Hỗ trợ tiếng Việt và tăng cỡ chữ hệ thống. Không ép text fit bằng cách làm bé khó đọc.
- Chạm tối thiểu khoảng 48dp, SafeArea và bàn phím không che CTA; không làm nút màu khác nhau tùy hứng.
- Mobile bottom nav: Tổng quan / Chuồng trại / Vật nuôi / Lịch / Thêm. Chức năng khác qua Thêm theo quyền. Desktop vẫn có bố cục phù hợp.
- Không dựng viền điện thoại, status bar giả, tên/số màn hoặc nền canvas của board vào sản phẩm.

## Những chi tiết trong ảnh cần hiểu đúng

1. 44 view không đồng nghĩa 44 route mới. Có thể là tab, dialog, bottom sheet hoặc cùng form thêm/sửa.
2. Chữ, người, mã, ngày, số lượng, tiền và thời tiết đều minh họa; chỉ lấy từ model/API thực khi triển khai.
3. Ảnh cá thể người dùng tải lên phải ưu tiên. Sticker theo loài chỉ làm fallback/trang trí. Không thay hết ảnh thật bằng cùng một con bò.
4. Chuồng không có loài cố định theo A1/B1/C1. Nếu thiếu dữ liệu hoặc hỗn hợp loài, dùng icon chuồng hoặc nhiều loài; không làm request nặng để trang trí.
5. Chọn ảnh hiện có dùng file selector; icon camera không tự cho phép thêm chức năng chụp ảnh.
6. Lịch chăm sóc hiện dùng ngày, không có giờ hẹn. Loại chỉ VACCINATION/CHECKUP; không tạo loại thứ ba từ ảnh.
7. Vòng đời vật nuôi ACTIVE/DEAD/SOLD tách khỏi sức khỏe NORMAL/NEEDS_CARE. Không sáng tạo trạng thái thứ ba hoặc chẩn đoán tự động.
8. Chẩn đoán trong khám EXAM phải theo validation thật. Không biến trường tùy chọn thành bắt buộc hoặc ngược lại theo dấu * trong ảnh.
9. Những trường chưa có trong model như ghi chú cho giống, địa chỉ dạng chữ, ngày tham gia tài khoản hay nhà cung cấp trong phiếu thu chi không tự bổ sung. Điều chỉnh nội dung UI theo code và ghi nhận khác biệt ngắn.
10. Số lượng kho/cân là kg, tiền là số nguyên VND theo logic đang có. Khi nhập số phải giữ chính xác dấu thập phân và format.
11. Doanh thu bán đã nằm trong Tổng thu. Chênh lệch thu chi chưa phải lợi nhuận kế toán.
12. Lịch sử thu chi là audit tài chính, không phải hóa đơn mua hàng có số lượng và đơn giá.
13. Các trạng thái empty/network error phải dựa vào trạng thái thật. Ảnh 44 minh họa nhiều thành phần; không dựng modal khóa và form nhập lỗi đồng thời.
14. Màn bán, hủy bán, ghi chết, khóa/xóa dùng lời giải thích ngắn, rõ hậu quả; không thêm chúc mừng hoặc hình minh họa đùa cợt.
15. Quyền và dữ liệu trong code là căn cứ nghiệp vụ. Nếu code có vẻ lỗi thật, báo bằng chứng và đề xuất thay vì tự khẳng định ảnh đúng hơn.

## Vai trò cần giữ

- ADMIN: chủ trong đúng trại; quản lý danh mục/nhân sự, bán/hủy bán, ghi chết và các nghiệp vụ được cấp. Bảo vệ tài khoản chủ theo code.
- STAFF: vận hành vật nuôi, cân/chuyển chuồng, kho, quan sát và lập lịch theo quyền; không xác nhận hoàn thành chăm sóc, không bán hoặc quản lý thu chi/nhân sự.
- VET: ghi chuyên môn thú y và hoàn thành chăm sóc; không được điều khiển kho, bán, tài chính hoặc nhân sự.
- ACCOUNTANT: sổ thu chi thủ công và báo cáo; không được bán/hủy bán hay vận hành trái quyền.
- Cả UI và backend đang có cơ chế kiểm soát; thay giao diện không nới quyền. Không giả định ẩn nút đủ thay cho server check.
- Giữ màn khởi đầu theo vai trò; menu mới không được làm mất quyền truy cập chức năng được phép.

## Bản đồ code ban đầu

- lib/core/theme.dart: theme, Brand, FeedbackBox.
- lib/core/api_client.dart: API_URL; không đổi địa chỉ production để phục vụ việc làm đẹp.
- lib/features/home/workspace_page.dart: navigation và setup theo vai trò.
- lib/features/auth/: login/controller/repository/token/profile role helpers.
- lib/features/farm/dashboard_page.dart, weather_card.dart, revenue_chart.dart.
- lib/features/farm/farm_pages.dart: CatalogPage, AnimalsPage, AnimalDetailPage, CarePage và form nghiệp vụ.
- lib/features/farm/animal_editor.dart: editor vật nuôi và thêm nhanh danh mục.
- lib/features/farm/farm_widgets.dart: FarmBody, farmForm, xác nhận và widget chung.
- lib/features/farm/inventory_page.dart, finance_page.dart.
- lib/features/users/: nhân sự.
- lib/features/home/profile_page.dart: tài khoản/đổi mật khẩu.
- test/: bộ kiểm thử Flutter hiện có. backend/: Node/TypeScript/Fastify/PostgreSQL; chỉ đọc khi cần xác minh hợp đồng.

## Asset

Bộ board nằm trong reference/ chỉ dùng tham khảo, không phải asset giao diện để nhét vào app.
Bước 02 tạo asset riêng, lưu assets/ và khai báo pubspec. Nếu dùng imagegen, tuân thủ skill tương ứng, ưu tiên tool tích hợp; không tự yêu cầu API key khi không cần.
Không tự lấy ảnh mạng không rõ nguồn hoặc phụ thuộc URL ngoài lúc chạy. Asset minh họa cần fallback phù hợp và không che nội dung.

## Kiểm tra và bằng chứng hoàn thành

- Trước sửa: đọc baseline trong PROGRESS.md và git diff để phân biệt lỗi cũ/thay đổi có sẵn.
- Mỗi bước: flutter analyze và các test thực sự bị ảnh hưởng; không viết test chỉ để khẳng định hằng màu hay mirror implementation. Chỉ thêm/sửa test khi cần bảo vệ hành vi.
- Giữ assertion về quyền, validation, giao dịch và dữ liệu. Có thể cập nhật selector/layout expectation khi UI thay đúng yêu cầu; không xóa test cho qua.
- Kiểm tra ở chiều rộng khoảng 360/412dp, màn rộng và text scale 1.3 nếu tooling cho phép. Form phải cuộn với keyboard, tên dài và lỗi nhiều dòng.
- Chụp preview từ app thật bằng thiết bị/emulator/web preview có sẵn; không dùng ảnh ImageGen làm bằng chứng implementation.
- Dùng local API/data hoặc fixture/test khi thao tác ghi. Không tự seed/reset DB production, đăng ký demo hoặc sửa/xóa dữ liệu online để chụp ảnh. Không đưa password/token vào log hay screenshot.
- Không chờ backend/cloud khi chỉ cần kiểm thử layout có thể dùng fixture tách trong test/preview; không hardcode fixture vào luồng production.
- Nếu không có môi trường preview, ghi rõ chưa kiểm chứng trực quan; không gọi chỉ analyze/test là đã khớp ảnh.
- Không khẳng định 90/46 test luôn còn đúng, hoặc đã test Android khi mới chạy Web.
- Toàn bộ test, build web và build Android kiểm tra tổng hợp ở bước 17. Nếu bước thay component dùng chung ảnh hưởng rộng, chạy kiểm tra rộng phù hợp.
- Tài liệu chạy local cũ có ở .local/HUONG_DAN.md và .local/run.ps1 nếu vẫn tồn tại. Kiểm tra môi trường thực; không cho rằng máy/SDK/device serial luôn giống phiên trước.

## Bàn giao giữa các chat

Sau mỗi bước, cập nhật đúng dòng trong PROGRESS.md: trạng thái, file đã sửa, kiểm tra đã chạy/kết quả, đường dẫn screenshot thật, khác biệt so với ảnh, vấn đề còn lại.
Không ghi bước Hoàn tất nếu thiếu asset/chức năng bắt buộc hoặc không thể xác minh phần quan trọng.
Kết thúc trả lời ngắn bằng tiếng Việt: đã làm gì; đã kiểm tra gì; ảnh xem ở đâu; còn vướng gì. Nêu bước kế tiếp gợi ý, không tự làm bước đó.

## Tham chiếu cách viết prompt

Bộ prompt được tổ chức theo mục tiêu, bối cảnh, ràng buộc và tiêu chí hoàn thành; tài liệu chính thức:
https://learn.chatgpt.com/docs/prompting
https://learn.chatgpt.com/guides/best-practices

