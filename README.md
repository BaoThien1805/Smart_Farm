# Smart Farm

Ứng dụng quản lý trang trại, gồm Flutter và REST API dùng Node.js, TypeScript, Fastify, PostgreSQL.

## Chức năng

- Đăng ký chủ trang trại, chọn loài đang nuôi; đăng nhập, đăng xuất và phân quyền theo trang trại.
- Quản lý loài, giống, khu vực, chuồng và hồ sơ vật nuôi có ảnh đại diện.
- Trong **Chuồng trại → ⋮ → Sửa → Chọn icon**, chọn icon có sẵn, dùng Tự động theo vật nuôi hoặc tải ảnh PNG/JPEG mới; icon lưu riêng cho từng chuồng và hiển thị cả ở Tổng quan.
- Chuyển chuồng, ghi cân nặng, theo dõi sức khỏe; đặt lịch chăm sóc cho một con, nhiều con hoặc nhiều chuồng trong cùng đợt.
- Menu ba chấm ở danh sách vật nuôi cho phép chọn nhiều con để chuyển chuồng hoặc đặt lịch; chủ trang trại có thể bán hoặc ghi nhận chết theo đợt. Bán ghi rõ giá mỗi con và tổng tiền, tạo giao dịch/khoản thu riêng. Các thao tác lưu cả đợt, chống trùng khi thử lại và giữ lịch sử từng con.
- Thẻ QR riêng cho từng vật nuôi; quét camera, đọc ảnh hoặc dán mã để mở hồ sơ, xuất/in PDF A6 theo theme ứng dụng.
- Bác sĩ thú y hoặc chủ xác nhận hoàn thành chăm sóc; nhân viên không có quyền xác nhận.
- Quản lý kho thức ăn, nhập/xuất, hủy giao dịch và cảnh báo tồn thấp.
- Bán vật nuôi liên kết phiếu thu; ghi thu chi, thống kê và biểu đồ doanh thu.
- Quản lý nhân sự, ảnh đại diện, sửa thông tin, khóa/mở khóa và xóa tài khoản theo quy tắc giữ lịch sử.
- Hiển thị thời tiết theo vị trí trang trại đã lưu.

Bốn vai trò: ADMIN (chủ trang trại), STAFF (nhân viên), VET (bác sĩ thú y), ACCOUNTANT (kế toán).

## Chạy bộ demo đầy đủ

Trên Windows, chạy `.\Start-Demo.ps1` từ thư mục dự án. Bộ demo có đủ vai trò,
12 loài, lịch sử nuôi, kho, thu chi và tình huống kiểm tra phân quyền. Xem
[tài khoản và kịch bản trình diễn](docs/DEMO.md). Script giữ dữ liệu cũ và không
nhân đôi bộ demo khi chạy lại.

## Cài Android dùng API online

Build với cấu hình online để điện thoại truy cập API mà không phụ thuộc máy tính
hay chuyển tiếp cổng USB:

```powershell
flutter build apk --debug --dart-define-from-file=config/online.json
adb install -r build/app/outputs/flutter-apk/app-debug.apk
```

`API_URL` được cố định lúc build. APK đã build với `127.0.0.1` vẫn dùng API local
dù mã nguồn hoặc file cấu hình sau đó đã đổi; cần build và cài lại bản online.
Lệnh cài `-r` giữ dữ liệu ứng dụng khi APK có cùng chữ ký.
Tài khoản và dữ liệu trên backend local không tự đồng bộ lên backend online;
cần dùng tài khoản đã đăng ký trên server online.

## Thời tiết

Ô thời tiết ở Tổng quan hiển thị tỉnh/thành theo tọa độ trang trại đã lưu.
Backend tra địa danh qua [Photon](https://github.com/komoot/photon), dữ liệu
© OpenStreetMap contributors (ODbL), lưu cache 24 giờ và gộp yêu cầu cùng tọa độ.
Nếu tra địa danh thất bại, nhiệt độ vẫn hiển thị cùng nhãn “Chưa rõ vị trí”.
Muốn dùng vị trí hiện tại, vào **Vị trí trang trại → Lấy vị trí thiết bị → Lưu vị trí**.

Chủ trang trại đặt tọa độ trong **Vị trí trang trại**. Backend mặc định lấy dữ liệu
thật từ [Open-Meteo](https://open-meteo.com/en/docs), không cần API key cho đồ án
phi thương mại. Dữ liệu theo mô hình thời tiết, không phải cảm biến tại trang trại;
ứng dụng hiển thị nguồn, thời điểm dữ liệu và ghi nguồn CC BY 4.0. Cache 10 phút,
gộp request cùng tọa độ; lỗi mạng vẫn hiển thị thông báo và cho thử lại.

Nếu cấu hình `WEATHER_API_KEY` hợp lệ trên backend, ứng dụng tiếp tục dùng
OpenWeather. Không đặt API key trong APK. Bản dùng Open-Meteo cần tuân thủ
[điều kiện sử dụng phi thương mại](https://open-meteo.com/en/terms).

