# Lượt sửa tích hợp sau review C — 25/10/2026

Tham chiếu: [Review sau triển khai](REVIEW-20261025.md). Thực hiện theo thứ tự F01 → header/layout → asset/nội dung/ngày → chuẩn bị smoke test Android.

## 1. F01 — Làm mới dữ liệu khi quay lại màn

- Workspace tăng revision khi kích hoạt lại Chuồng trại, Vật nuôi, Kho, Thu chi và Danh mục. Chọn lại đúng tab hiện tại không tạo lượt tải mới.
- Các page xử lý revision bằng tải lại dữ liệu, giữ nguyên State, tìm kiếm, bộ lọc, trang và tab con; không thay key để dựng lại page.
- `FarmRefresh` gộp các yêu cầu kích hoạt trong khi đang tải thành một lượt tải tiếp theo, tránh request đồng thời và tránh giữ kết quả được yêu cầu trước thao tác ở màn khác.
- Thay đổi tìm kiếm/bộ lọc ở Vật nuôi và Thu chi vẫn được phép gửi request mới ngay. Cơ chế generation hiện có loại phản hồi cũ; không bắt người dùng chờ một request tìm kiếm cũ bị chậm.
- Form dùng dialog/route riêng, không bị tháo State khi đổi revision. Kiểm thử giữ nháp tài khoản và resize vẫn nằm trong bộ kiểm thử.

Kiểm thử hồi quy `test/workspace_freshness_test.dart`:

1. Mở Chuồng → tạo cá thể qua repository → quay lại Chuồng: tải catalogs đúng một lượt và sức chứa đổi 1/10 → 2/10.
2. Mở Thu chi → bán qua repository ở tab Vật nuôi → quay lại Thu chi: tải report đúng một lượt, thu đổi 18.500.000 → 20.500.000.
3. Mở danh sách ACTIVE và tìm kiếm → hủy bán qua repository ở Thu chi → quay lại: cá thể xuất hiện, giữ tìm kiếm/trạng thái. Chọn lại tab không tải thêm.
4. Yêu cầu kích hoạt giữa request đang chạy: gộp thành một lượt tiếp theo, tối đa một lượt tải đồng thời.

Các mutation trong kiểm thử mới đi qua repository với MockClient có trạng thái. Đây là kiểm thử navigation/cache/HTTP local, không phải thao tác ghi lên PostgreSQL thật.

## 2. U01/U02 — Header và mật độ thông tin

- Mobile dùng tiêu đề của page. Workspace giữ AppBar cho Thêm; các page nghiệp vụ không còn AppBar trùng với tiêu đề nội dung.
- Nút Back về Thêm nằm trong header của các màn phụ; Back hệ thống và Back khi đang mở dialog vẫn được kiểm thử. Desktop giữ breadcrumb.
- Tổng quan bỏ banner và hai CTA lặp lối vào; rút lời chào, gộp icon/số trong thống kê và làm gọn bộ chọn nội dung. Bốn thống kê và việc cần làm xuất hiện sớm hơn, không giảm font toàn app.
- Thẻ chuồng gộp mã/khu vực, sức chứa/trạng thái, dùng menu Sửa/Xóa theo quyền. Bộ lọc chuồng chuyển vào vùng thu gọn, giữ lựa chọn khi chuyển tab.
- Thẻ vật nuôi dùng ảnh 56px, tên tối đa hai dòng và metadata một dòng; thông tin đầy đủ vẫn nằm trong hồ sơ. Trong workspace, bỏ lối vào Chuồng & danh mục lặp với điều hướng; lối vào của page độc lập vẫn hoạt động.
- Thẻ nhân sự gộp định danh, ảnh và trạng thái; sửa/khóa/mở khóa/xóa chuyển vào menu. Menu của chủ vẫn không có khóa/xóa; trạng thái tải lỗi vẫn khóa thao tác sửa.

Ảnh kiểm tra nằm tại `outputs/ui-redesign-c/integrated-fixes-20261025/`, gồm màn tích hợp 360×892 và 412×892, text scale 1.3, cùng ảnh stress tên dài của Chuồng/Vật nuôi/Nhân sự.

## 3. U03/U04 — Asset, nội dung, ngày

- Thêm sticker nhà chuồng trung tính `assets/illustrations/barn.png`, khai báo asset trong pubspec và dùng trong `FarmPenIllustration`. Giữ semantics Chuồng trại và icon dự phòng khi ảnh không tải được. Không suy đoán loài từ mã chuồng.
- Rút hướng dẫn trùng, bỏ banner trong form chuồng, thay chữ ADMIN trong hướng dẫn bằng Chủ trang trại. Giữ thông tin hậu quả, validation và quyền thao tác.
- Ngày trên danh sách, hồ sơ, lịch, sổ, lịch sử và trường ngày hiển thị `dd/MM/yyyy`. Trường nhập/bộ lọc chuyển về ISO khi tạo payload/query; các phép so sánh và thứ tự theo ngày vẫn dùng ISO.
- Bộ chuyển đổi ngày từ chối ngày không tồn tại, có kiểm tra ngày nhuận. Kiểm thử form xác nhận hiển thị `25/10/2026` nhưng callback lưu nhận `2026-10-25`.

### Nguồn asset nhà chuồng

Dùng công cụ imagegen tích hợp, nền trong suốt. PNG RGBA 1254×1254, alpha 0–255. File dùng trong dự án: `assets/illustrations/barn.png`.

Prompt đã dùng:

> Use case: stylized-concept. Asset type: transparent PNG sticker for a pastel cream Vietnamese farm management app, shown at 56 to 64 pixels. Primary request: one cute neutral farm barn, rounded proportions, soft peach walls, warm terracotta pitched roof, mint green double doors with cream cross braces, small loft window. Style: warm kawaii illustrated sticker, dark brown hand-drawn outlines, subtle cel shading, cream white sticker border, friendly cozy visual style. Composition: centered single barn, front three-quarter view, occupies most square frame with transparent padding. Constraints: truly transparent background, no text, no letters, no animals, no people, no ground scene, no watermark, no photo realism. Barn must remain readable as a simple small icon.

## 4. Kiểm tra Android/backend

Chưa thể đánh dấu hoàn tất smoke test Android:

- `flutter devices`: Windows, Chrome, Edge; không có Android.
- `adb devices`: không có thiết bị. `flutter emulators`: không có emulator.
- Đã thử 34 kiểm thử backend farm/inventory/finance/roles bằng PostgreSQL tách biệt. Chúng dừng ở before hook, chưa chạy được assertion nghiệp vụ.
- Chẩn đoán startup xác nhận PostgreSQL từ chối chạy vì tiến trình có quyền quản trị Windows: “Execution of PostgreSQL by a user with administrative permissions is not permitted.”
- Log: `.local/integrated-fixes-backend.log` và `.local/integrated-fixes-backend-diagnostic.log`. Cần chạy backend từ phiên Windows không nâng quyền để kiểm tra lại.

### Checklist cho lượt smoke còn lại

1. Mở phiên Windows không nâng quyền; chạy backend với cơ sở dữ liệu local riêng và tài khoản thử nghiệm. Không dùng tài khoản/dữ liệu thật.
2. Kết nối điện thoại Android qua USB debugging hoặc khởi động emulator. APK local dùng `http://127.0.0.1:3000/api`; chạy `adb reverse tcp:3000 tcp:3000` để nối tới backend trên máy tính.
3. Cài APK local, đăng nhập tài khoản thử. Mở trước Chuồng và Thu chi để tạo cache.
4. Thêm cá thể → quay lại Chuồng kiểm tra occupancy tự cập nhật; giữ thử bộ lọc và trang đã chọn.
5. Ghi cân → chuyển chuồng → kiểm tra hồ sơ, chuồng cũ/mới, Tổng quan và danh sách tự cập nhật.
6. Đặt lịch bằng STAFF; xác nhận STAFF không có nút hoàn thành. Hoàn thành bằng VET/chủ; kiểm tra lịch, sức khỏe và Tổng quan.
7. Nhập/xuất thức ăn → kiểm tra tồn và lịch sử; thử hủy bằng chủ với lý do.
8. Bán bằng chủ → kiểm tra ACTIVE, occupancy và phiếu thu/tổng thu. Hủy bán, chọn chuồng nhận lại → kiểm tra cá thể trở về ACTIVE và khoản thu được hủy.
9. Kiểm tra bàn phím, nút Back hệ thống, picker ảnh, GPS/quyền OS, font và text scale trên thiết bị thật. Chụp ảnh/log và ghi kết quả từng bước trước khi chốt end-to-end.

## Kết quả kiểm tra cuối

- `flutter test --reporter expanded --no-pub`: **553/553 đạt**, exit 0. Log: `.local/integrated-fixes-acceptance.log`.
- `flutter analyze --no-pub`: **No issues found**, exit 0. Log: `.local/integrated-fixes-analyze-acceptance.log`.
- Kiểm thử xuất ảnh tích hợp mobile 360/412, text scale 1.3: **2/2 đạt**. Ảnh đã được xem trực tiếp, bao gồm tiêu đề/Back, bốn thống kê, cảnh báo, việc cần làm, ảnh cá thể và sticker chuồng.
- Gallery stress Chuồng/Vật nuôi/Nhân sự 412px được xuất lại từ mã cuối; tổng cộng 13 PNG trong thư mục kết quả.
- Web preview với MockClient: **build thành công**, thư mục `.local/integrated-fixes-web`. Log: `.local/integrated-fixes-web-final.log`. Chưa coi build này là kiểm tra browser end-to-end.
- APK debug trỏ backend local: **build thành công**, `outputs/ui-redesign-c/integrated-fixes-20261025/smart-farm-local-debug.apk`. Lệnh build dùng `--dart-define=API_URL=http://127.0.0.1:3000/api`; cấu hình này chỉ thuộc bản APK local. Log: `.local/integrated-fixes-apk-local.log`.
- `git diff --check`: exit 0.

## Kết luận

Hoàn tất lượt sửa mã cho mục 1–3 của review: F01, U01–U04, kiểm thử hồi quy và ảnh kiểm tra. Không cần làm lại bộ 17 bước.

**Mục 4 chưa hoàn tất**: còn smoke test trên Android và kiểm tra giao dịch qua backend/PostgreSQL thật. APK và checklist đã sẵn sàng; cần thiết bị Android cùng phiên Windows không nâng quyền để thực hiện. Không đồng nhất kết quả mock/layout hoặc build APK với nghiệm thu end-to-end.
