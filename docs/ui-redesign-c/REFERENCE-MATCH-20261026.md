# Đối chiếu lại giao diện phương án C — 26/10/2026

Tham chiếu trực tiếp: `reference/nhom-01.png`, `nhom-02.png`, `nhom-03.png`, `nhom-10.png`.

## Những điểm đã sửa

- Nền kem sáng `#FFFCF5`, đường viền nhạt, radius thẻ 16 và ô nhập/nút 12; tiêu đề tròn Nunito ExtraBold, nội dung vẫn Roboto có tiếng Việt.
- Thay sáu PNG cũ bằng bộ chibi đầu lớn, thân nhỏ, viền nâu và mảng màu pastel: bò, heo, dê, gà, chuồng đỏ, phong cảnh. Tạo bằng công cụ imagegen tích hợp, đóng gói trong `assets/illustrations/`, giữ alpha cho sticker. Bản cũ được giữ ở `outputs/reference-c-refresh/before/` trên máy làm việc.
- Banner có cảnh trang trại và bò ở bên phải. Đăng nhập có bộ ba bò/heo/dê lớn như ảnh concept.
- Icon Thêm có màu riêng: túi thức ăn có lá, chồng tiền vàng, nhân sự xanh dương, danh mục tím. Thanh điều hướng dùng icon đặc khi chọn.
- Tổng quan có banner và ba ô số liệu, vẫn giữ số cần chăm sóc, lịch, cảnh báo, thời tiết và tài chính thật. Có các ô chuồng nhỏ khi backend trả danh sách chuồng.
- Chuồng có icon đúng loài đang nuôi, dựa trên `speciesNames` tổng hợp từ vật nuôi ACTIVE. Chuồng trống, hỗn hợp, hoặc backend cũ thiếu trường thì dùng hình chuồng. Không suy đoán loài theo mã chuồng, không thêm request cho mỗi chuồng.
- Danh sách vật nuôi dùng hình 72px và badge có chấm màu; bố cục gọn ở cỡ chữ thường, tách badge xuống dưới khi tăng cỡ chữ. Thao tác hồ sơ có nền xanh dương/đào/tím/mint theo mẫu.
- Font và component chung áp dụng cho form, kho, thu chi, lịch, nhân sự, tài khoản và QR. Giữ ảnh cá thể đã tải lên, API xác thực, validation và quyền của từng vai trò.

## Phần dữ liệu bổ sung để hiển thị đúng hình

`GET /api/farm/catalogs` thêm `pens[].speciesNames`; dashboard thêm `pens[]` cùng trường đó. Đây là trường chỉ đọc, tổng hợp trên dữ liệu cùng trại bằng cơ chế cô lập sẵn có. Không đổi bảng, dữ liệu vận hành, số con hoặc sức chứa.

Trình khởi động PostgreSQL local trên Windows dùng `pg_ctl` chính thức để chạy với token hạn chế khi editor chạy quyền Administrator. Không thay cài đặt bảo mật máy.

Ảnh PNG có vùng trong suốt được đặt trên nền trắng trước khi backend chuyển JPEG, tránh viền/nền đen. Ảnh JPEG và ảnh PNG không trong suốt giữ màu nội dung.

## Tài nguyên và prompt

Font Nunito lấy từ Google Fonts, giấy phép OFL trong `assets/fonts/nunito_license.txt`. Font được đóng gói, không tải mạng lúc chạy app.

Prompt bộ hình: [REFERENCE-ASSET-PROMPTS-20261026.md](REFERENCE-ASSET-PROMPTS-20261026.md).

Preview Flutter: `outputs/reference-c-refresh/after/`. Đây là dữ liệu fixture dùng kiểm tra bố cục; ảnh concept không được nhét làm màn hình trong ứng dụng.

Các khác biệt có chủ ý: nội dung và quyền theo dữ liệu thật, không tạo giờ hẹn không có trong model, không thay ảnh thật bằng sticker, không ẩn chức năng QR vừa bổ sung. Font hệ thống lớn được ưu tiên dễ đọc nên số cột có thể khác concept.

## Kết quả kiểm tra

- Flutter: 574 test đạt; `flutter analyze --no-pub` không còn vấn đề.
- Backend: build TypeScript đạt. 44 test đạt trong lượt toàn bộ; 6 test kho bị timeout lúc thiết lập database đã chạy lại riêng và cả 6 đạt. Thêm 1 test PNG trong suốt đạt. Test hiện có kiểm tra chuồng có đúng tập loài, chuồng hết vật nuôi có tập rỗng và dashboard khớp danh mục.
- Kiểm tra bố cục 360/412/1200px, chữ 1.3x; thêm kiểm tra thẻ vật nuôi gọn ở chữ 1x. Cả xem và điều hướng hồ sơ giữ đúng vòng đời/sức khỏe.
- Debug APK local đã cài cập nhật thành công trên TECNO LJ6, không xóa dữ liệu ứng dụng. Theo yêu cầu trực tiếp của người dùng, đã đăng nhập chủ trại demo và kiểm tra Tổng quan, Chuồng trại, Vật nuôi, hồ sơ BO-001, Thẻ QR, Lịch và Thêm (cả cuối trang). Các màn tải dữ liệu và điều hướng được; log Flutter/AndroidRuntime không có lỗi trong lượt này. Để tài khoản demo đăng nhập sẵn ở Tổng quan.
- Ảnh thật từ TECNO: `outputs/reference-c-refresh/after/tecno-overview.png`, `tecno-pens.png`, `tecno-animals.png`, `tecno-profile.png`, `tecno-qr.png`, `tecno-care.png`, `tecno-more.png`, `tecno-more-bottom.png`. Kiểm tra thẻ QR hiển thị được; không coi đây là bằng chứng thử camera quét mã.
- Backend demo local đã chạy lại với trường dữ liệu mới. Đã thay đúng 4 ảnh minh họa demo còn khớp nội dung ảnh seed cũ; không ghi đè ảnh cá thể đã được thay riêng.

Log kiểm tra nằm trong `.local/recheck-20261025/reference-*` (thư mục kiểm tra được bắt đầu từ lượt trước, giữ tên để liên tục hồ sơ).
