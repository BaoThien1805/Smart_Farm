# Toàn bộ prompt Smart Farm C

Mỗi phần bên dưới có thể copy độc lập. Mở cùng repo và giữ thư mục ảnh reference/. Không gửi cả file này để Codex tự chạy 18 bước một lần.

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


---

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


---

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


---

# Prompt 03 — Điều hướng và màn Thêm

Bạn đang làm trên dự án Flutter Smart Farm, đồ án cuối kỳ môn Phát triển ứng dụng di động đa nền tảng, repo https://github.com/BaoThien1805/Smart_Farm.
Workspace ban đầu: C:\Users\PC\Downloads\smart_farm. Nếu đang ở checkout khác của đúng repo, dùng root hiện tại; không tự clone lại.
Đây là chat mới: khôi phục bối cảnh bằng cách đọc docs/ui-redesign-c/BRIEF.md, PROGRESS.md cùng thư mục, AGENTS.md thực sự áp dụng và code hiện tại. Không giả định lịch sử chat trước.
Người dùng chọn phong cách C: nền kem, màu pastel, icon sticker bò/heo/dê cute, thông tin dễ đọc. Chỉ làm đúng bước 03; chưa tự làm bước kế tiếp.

Điều kiện trước bước: 01, 02 phải có kết quả phù hợp; kiểm tra cả code thật và PROGRESS.md. Nếu chưa đủ, báo ngắn và dừng phần phụ thuộc, không tự làm cả chuỗi.
Ảnh cần MỞ XEM: docs/ui-redesign-c/reference/nhom-01.png; docs/ui-redesign-c/reference/nhom-02.png; docs/ui-redesign-c/reference/nhom-03.png; docs/ui-redesign-c/reference/nhom-10.png.
Điểm bắt đầu trong code: lib/features/home/workspace_page.dart; lib/features/auth/auth_repository.dart; test/roles_test.dart.

## Công việc
Đổi bố cục điều hướng mobile sang 5 mục của C: Tổng quan, Chuồng trại, Vật nuôi, Lịch, Thêm.
- Tạo màn Thêm với lối vào Kho thức ăn, Thu chi, Nhân sự, Danh mục, Tài khoản, Vị trí trang trại theo quyền thực tế.
- Giữ đúng màn khởi đầu theo vai trò đang có: STAFF tới vật nuôi, VET tới chăm sóc, ACCOUNTANT tới thu chi, ADMIN tới Tổng quan sau thiết lập. Không dùng index cứng khiến chuyển tab mở nhầm màn.
- Chuồng trại là lối vào chức năng chuồng có sẵn; Danh mục là loài/giống/khu vực. Chưa cần vẽ lại nội dung từng trang trong bước này.
- Giữ các route/callback đang được dùng, nút Back Android và trạng thái selected hợp lý khi vào màn con từ Thêm. Tránh AppBar trùng hai tầng.
- Desktop/Web vẫn có navigation thích hợp; không ép khung điện thoại trên màn rộng.
Hoàn thành khi mọi chức năng cũ còn truy cập được, menu tôn trọng vai trò, đổi tab/Back không mất luồng nhập hoặc mở sai page. Kiểm tra navigation và phân quyền bằng các test liên quan; chưa làm thay nội dung bước 04–16.

## Cách xử lý khi thấy chưa ổn
Áp dụng quy tắc dừng trong BRIEF.md: nếu cần đổi nghiệp vụ/API/quyền hoặc gặp vướng quan trọng, dừng phần đó và góp ý 4–6 dòng: Vướng / Ảnh hưởng / Đề xuất 1–2 cách. Hỏi một câu nếu cần quyết định. Các chi tiết UI nhỏ được tự xử lý; không hỏi xác nhận kế hoạch thông thường.

## Bàn giao
Bảo toàn thay đổi có sẵn; không hardcode số liệu mẫu vào app hoặc sửa backend cho giống ảnh. Kiểm tra đúng phạm vi, xem preview thật nếu có thể, cập nhật PROGRESS.md với bằng chứng và phần chưa xác minh. Trả lời tiếng Việt ngắn: kết quả, kiểm tra, ảnh thật, vướng mắc. Không tự commit/push/deploy.


---

# Prompt 04 — Đăng nhập, đăng ký và chọn loài

Bạn đang làm trên dự án Flutter Smart Farm, đồ án cuối kỳ môn Phát triển ứng dụng di động đa nền tảng, repo https://github.com/BaoThien1805/Smart_Farm.
Workspace ban đầu: C:\Users\PC\Downloads\smart_farm. Nếu đang ở checkout khác của đúng repo, dùng root hiện tại; không tự clone lại.
Đây là chat mới: khôi phục bối cảnh bằng cách đọc docs/ui-redesign-c/BRIEF.md, PROGRESS.md cùng thư mục, AGENTS.md thực sự áp dụng và code hiện tại. Không giả định lịch sử chat trước.
Người dùng chọn phong cách C: nền kem, màu pastel, icon sticker bò/heo/dê cute, thông tin dễ đọc. Chỉ làm đúng bước 04; chưa tự làm bước kế tiếp.

Điều kiện trước bước: 01, 02, 03 phải có kết quả phù hợp; kiểm tra cả code thật và PROGRESS.md. Nếu chưa đủ, báo ngắn và dừng phần phụ thuộc, không tự làm cả chuỗi.
Ảnh cần MỞ XEM: docs/ui-redesign-c/reference/nhom-01.png.
Điểm bắt đầu trong code: lib/features/auth/login_page.dart; lib/features/farm/species_chooser.dart; lib/features/auth/auth_controller.dart.

## Công việc
Sửa màn 01–03: Đăng nhập, Đăng ký chủ trại và Chọn loài nuôi.
- Dùng banner và icon đã có từ bước 02; phần minh họa không đẩy ô nhập/nút chính ra ngoài khi bàn phím mở.
- Giữ đúng tên trường, password rules, hiển thị/ẩn mật khẩu, autofill, validation, chống submit lặp, thông báo lỗi và luồng đăng ký hiện có.
- Chọn loài bằng thẻ có sticker và dấu chọn, lấy danh sách thật từ API, hỗ trợ nhiều loài và khôi phục lựa chọn. Không cố định chỉ bốn loài trong dữ liệu.
- Giữ hành vi owner lần đầu phải hoàn thành setup; nhân sự không bị đưa vào thiết lập dành cho chủ.
- Không thêm quên mật khẩu, đăng nhập mạng xã hội hoặc chức năng xác thực mới.
Hoàn thành khi đăng nhập/đăng ký/chọn loài vẫn dùng controller/API cũ, màn nhỏ và bàn phím không che thao tác. Chạy test auth/species/workflow tương ứng và chụp preview thật của các màn có thể chạy local.

## Cách xử lý khi thấy chưa ổn
Áp dụng quy tắc dừng trong BRIEF.md: nếu cần đổi nghiệp vụ/API/quyền hoặc gặp vướng quan trọng, dừng phần đó và góp ý 4–6 dòng: Vướng / Ảnh hưởng / Đề xuất 1–2 cách. Hỏi một câu nếu cần quyết định. Các chi tiết UI nhỏ được tự xử lý; không hỏi xác nhận kế hoạch thông thường.

## Bàn giao
Bảo toàn thay đổi có sẵn; không hardcode số liệu mẫu vào app hoặc sửa backend cho giống ảnh. Kiểm tra đúng phạm vi, xem preview thật nếu có thể, cập nhật PROGRESS.md với bằng chứng và phần chưa xác minh. Trả lời tiếng Việt ngắn: kết quả, kiểm tra, ảnh thật, vướng mắc. Không tự commit/push/deploy.


---

# Prompt 05 — Tổng quan, thời tiết và vị trí trại

Bạn đang làm trên dự án Flutter Smart Farm, đồ án cuối kỳ môn Phát triển ứng dụng di động đa nền tảng, repo https://github.com/BaoThien1805/Smart_Farm.
Workspace ban đầu: C:\Users\PC\Downloads\smart_farm. Nếu đang ở checkout khác của đúng repo, dùng root hiện tại; không tự clone lại.
Đây là chat mới: khôi phục bối cảnh bằng cách đọc docs/ui-redesign-c/BRIEF.md, PROGRESS.md cùng thư mục, AGENTS.md thực sự áp dụng và code hiện tại. Không giả định lịch sử chat trước.
Người dùng chọn phong cách C: nền kem, màu pastel, icon sticker bò/heo/dê cute, thông tin dễ đọc. Chỉ làm đúng bước 05; chưa tự làm bước kế tiếp.

Điều kiện trước bước: 01, 02, 03 phải có kết quả phù hợp; kiểm tra cả code thật và PROGRESS.md. Nếu chưa đủ, báo ngắn và dừng phần phụ thuộc, không tự làm cả chuỗi.
Ảnh cần MỞ XEM: docs/ui-redesign-c/reference/nhom-01.png; docs/ui-redesign-c/reference/nhom-10.png.
Điểm bắt đầu trong code: lib/features/farm/dashboard_page.dart; lib/features/farm/weather_card.dart; lib/core/device_location.dart; test/dashboard_test.dart; test/weather_card_test.dart; test/device_location_test.dart.

## Công việc
Sửa màn 04 và 38 theo C.
- Tổng quan có header nông trại nhỏ, thẻ số liệu, việc cần làm, cảnh báo và lối vào các chức năng. Tận dụng API/dashboard hiện có; không hardcode 36 vật nuôi, 6 chuồng, tên trại hay cảnh báo mẫu.
- Các khối tài chính chỉ xuất hiện với người có quyền. Giữ báo cáo/biểu đồ hiện có, không làm mất chức năng vì ảnh concept không thể hiện hết.
- Thời tiết hiển thị dữ liệu thật, trạng thái tải/thiếu key/lỗi riêng, không biến mất toàn bộ Tổng quan khi dịch vụ thời tiết lỗi.
- Vị trí trại giữ chức năng lấy GPS, nhập vĩ độ/kinh độ, lưu/xóa nếu đang có và xử lý quyền vị trí. Không tự thêm bản đồ, geocoding hay địa chỉ dạng chữ chưa được API hỗ trợ.
- Chỉ hiển thị chi tiết chuồng khi có dữ liệu phù hợp; nếu API không có một khối, dùng lối vào chức năng hiện có hoặc đề xuất gọn thay vì fake dữ liệu.
Hoàn thành khi mỗi thẻ/CTA mở đúng màn, dữ liệu live đúng quyền và layout không tràn. Chạy test dashboard/weather/location, báo rõ phần chưa kiểm tra được trên thiết bị thật.

## Cách xử lý khi thấy chưa ổn
Áp dụng quy tắc dừng trong BRIEF.md: nếu cần đổi nghiệp vụ/API/quyền hoặc gặp vướng quan trọng, dừng phần đó và góp ý 4–6 dòng: Vướng / Ảnh hưởng / Đề xuất 1–2 cách. Hỏi một câu nếu cần quyết định. Các chi tiết UI nhỏ được tự xử lý; không hỏi xác nhận kế hoạch thông thường.

## Bàn giao
Bảo toàn thay đổi có sẵn; không hardcode số liệu mẫu vào app hoặc sửa backend cho giống ảnh. Kiểm tra đúng phạm vi, xem preview thật nếu có thể, cập nhật PROGRESS.md với bằng chứng và phần chưa xác minh. Trả lời tiếng Việt ngắn: kết quả, kiểm tra, ảnh thật, vướng mắc. Không tự commit/push/deploy.


---

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


---

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


---

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


---

# Prompt 09 — Form thêm và sửa vật nuôi

Bạn đang làm trên dự án Flutter Smart Farm, đồ án cuối kỳ môn Phát triển ứng dụng di động đa nền tảng, repo https://github.com/BaoThien1805/Smart_Farm.
Workspace ban đầu: C:\Users\PC\Downloads\smart_farm. Nếu đang ở checkout khác của đúng repo, dùng root hiện tại; không tự clone lại.
Đây là chat mới: khôi phục bối cảnh bằng cách đọc docs/ui-redesign-c/BRIEF.md, PROGRESS.md cùng thư mục, AGENTS.md thực sự áp dụng và code hiện tại. Không giả định lịch sử chat trước.
Người dùng chọn phong cách C: nền kem, màu pastel, icon sticker bò/heo/dê cute, thông tin dễ đọc. Chỉ làm đúng bước 09; chưa tự làm bước kế tiếp.

Điều kiện trước bước: 01, 02, 03, 06, 08 phải có kết quả phù hợp; kiểm tra cả code thật và PROGRESS.md. Nếu chưa đủ, báo ngắn và dừng phần phụ thuộc, không tự làm cả chuỗi.
Ảnh cần MỞ XEM: docs/ui-redesign-c/reference/nhom-03.png.
Điểm bắt đầu trong code: lib/features/farm/animal_editor.dart; lib/core/suggested_code_field.dart; lib/core/photo_picker.dart; test/workflow_improvements_test.dart; test/photo_workflow_test.dart.

## Công việc
Sửa màn 11: form thêm/sửa vật nuôi, dùng chung thiết kế.
- Giữ đủ toàn bộ trường hiện có dù mockup chỉ thể hiện một viewport: loài/giống, mã, tên, giới tính, các ngày, nguồn gốc, ghi chú, khu vực/chuồng, ảnh và các trường khác có trong code.
- Chia nhóm rõ, cuộn tự nhiên, nút Lưu không bị bàn phím che; label và lỗi không chỉ dựa vào placeholder.
- Giữ gợi ý mã và validation phía client/server; không bắt trường đang tùy chọn thành bắt buộc theo dấu * trong ảnh.
- Bảo toàn dữ liệu nháp khi thêm nhanh khu vực/chuồng/giống từ form. STAFF không được mở chức năng danh mục dành riêng ADMIN.
- Giữ xử lý ảnh thêm/giữ/xóa và validation kích thước; không thay đường upload.
Hoàn thành khi thêm/sửa/cancel/nhập lỗi hoạt động như cũ, không mất nháp qua form lồng, không cho lưu hai lần. Chạy các test workflow/photo/suggestion và kiểm tra bàn phím mobile.

## Cách xử lý khi thấy chưa ổn
Áp dụng quy tắc dừng trong BRIEF.md: nếu cần đổi nghiệp vụ/API/quyền hoặc gặp vướng quan trọng, dừng phần đó và góp ý 4–6 dòng: Vướng / Ảnh hưởng / Đề xuất 1–2 cách. Hỏi một câu nếu cần quyết định. Các chi tiết UI nhỏ được tự xử lý; không hỏi xác nhận kế hoạch thông thường.

## Bàn giao
Bảo toàn thay đổi có sẵn; không hardcode số liệu mẫu vào app hoặc sửa backend cho giống ảnh. Kiểm tra đúng phạm vi, xem preview thật nếu có thể, cập nhật PROGRESS.md với bằng chứng và phần chưa xác minh. Trả lời tiếng Việt ngắn: kết quả, kiểm tra, ảnh thật, vướng mắc. Không tự commit/push/deploy.


---

# Prompt 10 — Ghi cân, chuyển chuồng, sức khỏe và thú y

Bạn đang làm trên dự án Flutter Smart Farm, đồ án cuối kỳ môn Phát triển ứng dụng di động đa nền tảng, repo https://github.com/BaoThien1805/Smart_Farm.
Workspace ban đầu: C:\Users\PC\Downloads\smart_farm. Nếu đang ở checkout khác của đúng repo, dùng root hiện tại; không tự clone lại.
Đây là chat mới: khôi phục bối cảnh bằng cách đọc docs/ui-redesign-c/BRIEF.md, PROGRESS.md cùng thư mục, AGENTS.md thực sự áp dụng và code hiện tại. Không giả định lịch sử chat trước.
Người dùng chọn phong cách C: nền kem, màu pastel, icon sticker bò/heo/dê cute, thông tin dễ đọc. Chỉ làm đúng bước 10; chưa tự làm bước kế tiếp.

Điều kiện trước bước: 01, 02, 08, 09 phải có kết quả phù hợp; kiểm tra cả code thật và PROGRESS.md. Nếu chưa đủ, báo ngắn và dừng phần phụ thuộc, không tự làm cả chuỗi.
Ảnh cần MỞ XEM: docs/ui-redesign-c/reference/nhom-04.png; docs/ui-redesign-c/reference/nhom-10.png.
Điểm bắt đầu trong code: lib/features/farm/farm_pages.dart: AnimalDetailPage.event; lib/features/farm/farm_widgets.dart; test/roles_test.dart; test/farm_test.dart.

## Công việc
Sửa các form màn 13–16 và 40: ghi cân, chuyển chuồng, quan sát sức khỏe, khám thú y, ghi nhận chết.
- Dùng header cá thể gọn, trường nhập rõ, nút xác nhận phù hợp mức độ thao tác.
- Cân nặng giữ độ chính xác tối đa ba số lẻ theo luồng hiện tại; giữ parse/format không đổi 215,500 thành 215500 kg. Chuồng đích chỉ hiển thị lựa chọn đúng trạng thái/sức chứa.
- Quan sát sức khỏe và khám là hai nghiệp vụ khác nhau. STAFF được quan sát nhưng không được ghi chẩn đoán. Chẩn đoán trong khám thú y bắt buộc theo code; điều trị theo quy tắc hiện có.
- Hai tình trạng sức khỏe là NORMAL/NEEDS_CARE; tên hiển thị tương đương Bình thường/Cần chăm sóc. Không tạo thêm trạng thái từ ảnh.
- Ghi nhận chết chỉ ADMIN khi hợp lệ, có xác nhận rõ hậu quả; giữ lịch sử và callback hiện có.
- Chỉ trình bày chênh lệch cân nếu có dữ liệu trước đó và tính được chính xác; không thêm dự báo/AI.
Hoàn thành khi các quyền, validation, requestId và cập nhật hồ sơ được giữ nguyên. Chạy các test form/role/nghiệp vụ có liên quan; không sửa backend để hợp mockup.

## Cách xử lý khi thấy chưa ổn
Áp dụng quy tắc dừng trong BRIEF.md: nếu cần đổi nghiệp vụ/API/quyền hoặc gặp vướng quan trọng, dừng phần đó và góp ý 4–6 dòng: Vướng / Ảnh hưởng / Đề xuất 1–2 cách. Hỏi một câu nếu cần quyết định. Các chi tiết UI nhỏ được tự xử lý; không hỏi xác nhận kế hoạch thông thường.

## Bàn giao
Bảo toàn thay đổi có sẵn; không hardcode số liệu mẫu vào app hoặc sửa backend cho giống ảnh. Kiểm tra đúng phạm vi, xem preview thật nếu có thể, cập nhật PROGRESS.md với bằng chứng và phần chưa xác minh. Trả lời tiếng Việt ngắn: kết quả, kiểm tra, ảnh thật, vướng mắc. Không tự commit/push/deploy.


---

# Prompt 11 — Lịch chăm sóc và hoàn thành công việc

Bạn đang làm trên dự án Flutter Smart Farm, đồ án cuối kỳ môn Phát triển ứng dụng di động đa nền tảng, repo https://github.com/BaoThien1805/Smart_Farm.
Workspace ban đầu: C:\Users\PC\Downloads\smart_farm. Nếu đang ở checkout khác của đúng repo, dùng root hiện tại; không tự clone lại.
Đây là chat mới: khôi phục bối cảnh bằng cách đọc docs/ui-redesign-c/BRIEF.md, PROGRESS.md cùng thư mục, AGENTS.md thực sự áp dụng và code hiện tại. Không giả định lịch sử chat trước.
Người dùng chọn phong cách C: nền kem, màu pastel, icon sticker bò/heo/dê cute, thông tin dễ đọc. Chỉ làm đúng bước 11; chưa tự làm bước kế tiếp.

Điều kiện trước bước: 01, 02, 03, 08, 10 phải có kết quả phù hợp; kiểm tra cả code thật và PROGRESS.md. Nếu chưa đủ, báo ngắn và dừng phần phụ thuộc, không tự làm cả chuỗi.
Ảnh cần MỞ XEM: docs/ui-redesign-c/reference/nhom-05.png.
Điểm bắt đầu trong code: lib/features/farm/farm_pages.dart: CarePage and care forms; lib/features/farm/farm_widgets.dart; test/roles_test.dart; test/phase_4_test.dart.

## Công việc
Sửa màn 17–19: danh sách lịch, form đặt/sửa và form hoàn thành; dùng thiết kế lịch sử đã có ở bước 08.
- Nhóm công việc theo ngày, có nhãn quá hạn và trạng thái chờ/hoàn thành/đã hủy từ dữ liệu thật. Không gán giờ 09:00 khi API chỉ lưu ngày.
- Hai loại công việc hiện có là VACCINATION và CHECKUP. Không thêm loại Chăm sóc chung chỉ vì ảnh cũ có ô đó.
- Giữ các thao tác đặt/sửa/hủy theo quyền; STAFF lập lịch được nhưng không xác nhận hoàn thành. ADMIN/VET mới có thao tác hoàn thành hợp lệ.
- Hoàn thành có ngày thực tế, kết quả và sức khỏe theo model hiện tại; không biến nút bắt đầu thành tính năng quy trình mới chưa có.
- Không ghi chẩn đoán tự động, không sửa lịch đã đóng hoặc gửi lặp.
Hoàn thành khi trạng thái/chỉ số/dashboard cập nhật đúng sau thao tác, form chống submit lặp và quyền rõ ràng. Chạy test care/roles hiện có; kiểm tra các trạng thái không có lịch và lịch dài.

## Cách xử lý khi thấy chưa ổn
Áp dụng quy tắc dừng trong BRIEF.md: nếu cần đổi nghiệp vụ/API/quyền hoặc gặp vướng quan trọng, dừng phần đó và góp ý 4–6 dòng: Vướng / Ảnh hưởng / Đề xuất 1–2 cách. Hỏi một câu nếu cần quyết định. Các chi tiết UI nhỏ được tự xử lý; không hỏi xác nhận kế hoạch thông thường.

## Bàn giao
Bảo toàn thay đổi có sẵn; không hardcode số liệu mẫu vào app hoặc sửa backend cho giống ảnh. Kiểm tra đúng phạm vi, xem preview thật nếu có thể, cập nhật PROGRESS.md với bằng chứng và phần chưa xác minh. Trả lời tiếng Việt ngắn: kết quả, kiểm tra, ảnh thật, vướng mắc. Không tự commit/push/deploy.


---

# Prompt 12 — Kho, nhập xuất và lịch sử phiếu

Bạn đang làm trên dự án Flutter Smart Farm, đồ án cuối kỳ môn Phát triển ứng dụng di động đa nền tảng, repo https://github.com/BaoThien1805/Smart_Farm.
Workspace ban đầu: C:\Users\PC\Downloads\smart_farm. Nếu đang ở checkout khác của đúng repo, dùng root hiện tại; không tự clone lại.
Đây là chat mới: khôi phục bối cảnh bằng cách đọc docs/ui-redesign-c/BRIEF.md, PROGRESS.md cùng thư mục, AGENTS.md thực sự áp dụng và code hiện tại. Không giả định lịch sử chat trước.
Người dùng chọn phong cách C: nền kem, màu pastel, icon sticker bò/heo/dê cute, thông tin dễ đọc. Chỉ làm đúng bước 12; chưa tự làm bước kế tiếp.

Điều kiện trước bước: 01, 02, 03 phải có kết quả phù hợp; kiểm tra cả code thật và PROGRESS.md. Nếu chưa đủ, báo ngắn và dừng phần phụ thuộc, không tự làm cả chuỗi.
Ảnh cần MỞ XEM: docs/ui-redesign-c/reference/nhom-06.png; docs/ui-redesign-c/reference/nhom-07.png.
Điểm bắt đầu trong code: lib/features/farm/inventory_page.dart; lib/features/farm/farm_widgets.dart; test/phase_4_test.dart; test/roles_test.dart.

## Công việc
Sửa màn 21–26: tồn kho, thêm/sửa thức ăn, nhập/xuất, lịch sử và hủy phiếu.
- Dùng minh họa bao thức ăn nhỏ, số kg dễ đọc, nhãn tồn thấp có text và màu. Chỉ hiện cảnh báo khi dữ liệu/logic tồn thấp thật đáp ứng.
- Giữ tab, filter, phân trang, đơn vị kg, precision và form đang có. Không thêm đơn giá/dự báo ngày hết vì model kho hiện chưa có.
- Nhập/xuất dùng dữ liệu thật; xuất có chuồng không bắt buộc. Nếu hiển thị tồn sau xuất, tính từ giá trị hợp lệ trong form, không thay kiểm tra server.
- Chủ/nhân viên thao tác theo quyền hiện có; hủy phiếu ADMIN, có lý do và không xóa lịch sử.
- Tồn 0, số thập phân dài, phiếu đã hủy và giao dịch bị server từ chối phải hiển thị rõ; không tô mọi phiếu là thành công.
Hoàn thành khi luồng nhập/xuất/hủy vẫn dùng API/requestId cũ, kiểm tra tồn âm không bị bỏ qua và trạng thái refresh đúng. Chạy test kho/UI liên quan; dùng local/test fixture khi kiểm tra thao tác ghi.

## Cách xử lý khi thấy chưa ổn
Áp dụng quy tắc dừng trong BRIEF.md: nếu cần đổi nghiệp vụ/API/quyền hoặc gặp vướng quan trọng, dừng phần đó và góp ý 4–6 dòng: Vướng / Ảnh hưởng / Đề xuất 1–2 cách. Hỏi một câu nếu cần quyết định. Các chi tiết UI nhỏ được tự xử lý; không hỏi xác nhận kế hoạch thông thường.

## Bàn giao
Bảo toàn thay đổi có sẵn; không hardcode số liệu mẫu vào app hoặc sửa backend cho giống ảnh. Kiểm tra đúng phạm vi, xem preview thật nếu có thể, cập nhật PROGRESS.md với bằng chứng và phần chưa xác minh. Trả lời tiếng Việt ngắn: kết quả, kiểm tra, ảnh thật, vướng mắc. Không tự commit/push/deploy.


---

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


---

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


---

# Prompt 15 — Nhân sự và xác nhận khóa/xóa

Bạn đang làm trên dự án Flutter Smart Farm, đồ án cuối kỳ môn Phát triển ứng dụng di động đa nền tảng, repo https://github.com/BaoThien1805/Smart_Farm.
Workspace ban đầu: C:\Users\PC\Downloads\smart_farm. Nếu đang ở checkout khác của đúng repo, dùng root hiện tại; không tự clone lại.
Đây là chat mới: khôi phục bối cảnh bằng cách đọc docs/ui-redesign-c/BRIEF.md, PROGRESS.md cùng thư mục, AGENTS.md thực sự áp dụng và code hiện tại. Không giả định lịch sử chat trước.
Người dùng chọn phong cách C: nền kem, màu pastel, icon sticker bò/heo/dê cute, thông tin dễ đọc. Chỉ làm đúng bước 15; chưa tự làm bước kế tiếp.

Điều kiện trước bước: 01, 02, 03 phải có kết quả phù hợp; kiểm tra cả code thật và PROGRESS.md. Nếu chưa đủ, báo ngắn và dừng phần phụ thuộc, không tự làm cả chuỗi.
Ảnh cần MỞ XEM: docs/ui-redesign-c/reference/nhom-09.png; docs/ui-redesign-c/reference/nhom-11.png.
Điểm bắt đầu trong code: lib/features/users/users_page.dart; lib/features/users/users_controller.dart; lib/features/auth/user_avatar.dart; test/personnel_edit_test.dart; test/roles_test.dart.

## Công việc
Sửa màn 33, 34, 43, 44: danh sách nhân sự, form thêm/sửa, xác nhận khóa/mở khóa và xóa.
- Dùng avatar người thật nếu có, fallback trung tính cho con người; không dùng icon bò/heo đại diện cho nhân sự.
- Hiện mã, tên, email, vai trò và trạng thái; thao tác ADMIN và bảo vệ tài khoản chủ theo code. Không thêm vai trò hay cho tạo ADMIN mới.
- Form giữ khác biệt thêm/sửa, ảnh, gợi ý mã và validation mật khẩu ban đầu đang có. Không xuất mật khẩu thật ra log/screenshot.
- Khóa/mở khóa/xóa giải thích hậu quả ngắn, phân biệt xóa vật lý nếu chưa lịch sử và xóa mềm nếu đã liên kết. Không nói luôn luôn xóa dữ liệu hoặc luôn luôn giữ tài khoản.
- Modal khóa/xóa phải độc lập; không sao chép ảnh 44 thành hai modal/form đồng thời.
Hoàn thành khi sửa role/email/ảnh đúng luồng, bảo vệ chủ, thu hồi phiên và giữ lịch sử được giữ nguyên. Chạy test personnel/edit/roles liên quan; không tự tạo thêm filter cần endpoint mới.

## Cách xử lý khi thấy chưa ổn
Áp dụng quy tắc dừng trong BRIEF.md: nếu cần đổi nghiệp vụ/API/quyền hoặc gặp vướng quan trọng, dừng phần đó và góp ý 4–6 dòng: Vướng / Ảnh hưởng / Đề xuất 1–2 cách. Hỏi một câu nếu cần quyết định. Các chi tiết UI nhỏ được tự xử lý; không hỏi xác nhận kế hoạch thông thường.

## Bàn giao
Bảo toàn thay đổi có sẵn; không hardcode số liệu mẫu vào app hoặc sửa backend cho giống ảnh. Kiểm tra đúng phạm vi, xem preview thật nếu có thể, cập nhật PROGRESS.md với bằng chứng và phần chưa xác minh. Trả lời tiếng Việt ngắn: kết quả, kiểm tra, ảnh thật, vướng mắc. Không tự commit/push/deploy.


---

# Prompt 16 — Tài khoản và đổi mật khẩu

Bạn đang làm trên dự án Flutter Smart Farm, đồ án cuối kỳ môn Phát triển ứng dụng di động đa nền tảng, repo https://github.com/BaoThien1805/Smart_Farm.
Workspace ban đầu: C:\Users\PC\Downloads\smart_farm. Nếu đang ở checkout khác của đúng repo, dùng root hiện tại; không tự clone lại.
Đây là chat mới: khôi phục bối cảnh bằng cách đọc docs/ui-redesign-c/BRIEF.md, PROGRESS.md cùng thư mục, AGENTS.md thực sự áp dụng và code hiện tại. Không giả định lịch sử chat trước.
Người dùng chọn phong cách C: nền kem, màu pastel, icon sticker bò/heo/dê cute, thông tin dễ đọc. Chỉ làm đúng bước 16; chưa tự làm bước kế tiếp.

Điều kiện trước bước: 01, 02, 03, 15 phải có kết quả phù hợp; kiểm tra cả code thật và PROGRESS.md. Nếu chưa đủ, báo ngắn và dừng phần phụ thuộc, không tự làm cả chuỗi.
Ảnh cần MỞ XEM: docs/ui-redesign-c/reference/nhom-09.png.
Điểm bắt đầu trong code: lib/features/home/profile_page.dart; lib/features/auth/auth_controller.dart; lib/features/auth/auth_repository.dart; test/widget_test.dart; test/photo_workflow_test.dart.

## Công việc
Sửa màn 35–36: tài khoản cá nhân và đổi mật khẩu.
- Thông tin tên/email/mã/vai trò/tên trại hiển thị đúng model; không thêm địa chỉ/ngày tham gia cố định chỉ vì ảnh có.
- Ảnh thật được ưu tiên; quyền đổi avatar giữ đúng hiện tại. STAFF không có khả năng tự chỉnh thông tin mà backend chỉ cấp ADMIN.
- Form đổi mật khẩu giữ mật khẩu hiện tại/mới/xác nhận, validation đang có, show/hide, autofill, busy và thông báo lỗi.
- Giữ hành vi đổi mật khẩu thu hồi phiên/đăng nhập lại và logout xóa token; không thay TokenStore hay cơ chế lưu phiên.
- Giao diện cảm giác gần gũi nhưng thông báo bảo mật, đổi mật khẩu và đăng xuất phải rõ.
Hoàn thành khi đổi đúng/sai mật khẩu, đăng nhập lại, refresh profile và logout còn hoạt động như trước. Chạy test auth/profile/photo tương ứng và kiểm tra bàn phím trên màn nhỏ.

## Cách xử lý khi thấy chưa ổn
Áp dụng quy tắc dừng trong BRIEF.md: nếu cần đổi nghiệp vụ/API/quyền hoặc gặp vướng quan trọng, dừng phần đó và góp ý 4–6 dòng: Vướng / Ảnh hưởng / Đề xuất 1–2 cách. Hỏi một câu nếu cần quyết định. Các chi tiết UI nhỏ được tự xử lý; không hỏi xác nhận kế hoạch thông thường.

## Bàn giao
Bảo toàn thay đổi có sẵn; không hardcode số liệu mẫu vào app hoặc sửa backend cho giống ảnh. Kiểm tra đúng phạm vi, xem preview thật nếu có thể, cập nhật PROGRESS.md với bằng chứng và phần chưa xác minh. Trả lời tiếng Việt ngắn: kết quả, kiểm tra, ảnh thật, vướng mắc. Không tự commit/push/deploy.


---

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

