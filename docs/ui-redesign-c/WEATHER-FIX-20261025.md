# Sửa thời tiết thiếu cấu hình — 25/10/2026

## Nguyên nhân và thay đổi

Backend cũ dừng ở `WEATHER_NOT_CONFIGURED` khi không có `WEATHER_API_KEY`, dù trang trại đã lưu tọa độ. Đã cho `WeatherService` dùng Open-Meteo khi không có khóa; khi có khóa vẫn dùng OpenWeather. Khóa để trống được coi là chưa đặt. Không thêm dữ liệu thời tiết giả hoặc tọa độ mặc định.

Open-Meteo được gọi qua backend bằng tọa độ đã lưu, lấy current temperature/humidity/wind/weather code, yêu cầu °C, m/s và Unix UTC. Mã WMO được chuyển sang mô tả tiếng Việt và nhóm icon đang có của Flutter; không đưa mã WMO thẳng vào UI vốn dùng nhóm mã OpenWeather. Payload thiếu dữ liệu, sai đơn vị, mã không hỗ trợ và lỗi provider trả lỗi an toàn và cho retry. Giữ cache 10 phút, gộp request, giới hạn cache và timeout 8 giây.

Thẻ chi tiết đọc `provider` từ API thay vì ghi cứng OpenWeather; hiển thị nguồn Open-Meteo, URI và CC BY 4.0. README và .env.example hướng dẫn khóa tùy chọn, phạm vi dùng phi thương mại cho đồ án. Tham chiếu [API](https://open-meteo.com/en/docs) và [điều kiện dùng](https://open-meteo.com/en/terms).

## Kiểm chứng

- TypeScript build: đạt.
- Toàn bộ backend test: **49/49 đạt**, 0 bỏ qua. Chạy PostgreSQL thật với adapter pg_ctl của lượt review trước; thời tiết bên ngoài được mock trong suite để test không phụ thuộc mạng. Log `.local/recheck-20261025/weather-backend-tests.log`.
- Flutter weather/card/dashboard liên quan: **23/23 đạt**, gồm layout chữ lớn và assertion nguồn Open-Meteo/giờ Việt Nam. Log `weather-flutter-tests.log` trong cùng thư mục.
- `flutter analyze --no-pub`: không có issue; `git diff --check`: đạt.
- Gọi provider thật bằng tọa độ mẫu công khai: trả Open-Meteo và số liệu hợp lệ.
- Restart API local bằng script resume, giữ nguyên DB kiểm thử `smartfarm_android_b1769c97`, người dùng và phiên; không tạo lại/seed DB. `/api/weather` với token của trại hiện tại trả HTTP 200, provider Open-Meteo, 31.4°C, 61%, gió 1.77 m/s, thời điểm dữ liệu 09:00 UTC trong lượt kiểm tra.
- Build APK debug với `API_URL=http://127.0.0.1:3000/api`: đạt; cài cập nhật lên TECNO bằng `adb install -r`: thành công. Mở app khôi phục phiên, Tổng quan hiển thị 31°C; mở chi tiết và bấm cập nhật tiếp tục thành công, không còn thông báo thiếu cấu hình. Ảnh gốc `.local/recheck-20261025/android-weather-fixed.png`.

APK mới ở `build/app/outputs/flutter-apk/app-debug.apk`. API local đang chạy cổng 3001, USB reverse cổng 3000 tới 3001. Chưa push/deploy lên backend Render; kết quả trên điện thoại thuộc môi trường local đang kết nối. Không thay đổi vị trí đã lưu hoặc các giao dịch kiểm thử trước đó.
