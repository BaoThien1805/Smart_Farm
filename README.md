# Smart Farm

Ứng dụng quản lý trang trại, gồm Flutter và REST API dùng Node.js, TypeScript, Fastify, PostgreSQL.

## Chức năng

- Đăng ký chủ trang trại, chọn loài đang nuôi; đăng nhập, đăng xuất và phân quyền theo trang trại.
- Quản lý loài, giống, khu vực, chuồng và hồ sơ vật nuôi có ảnh đại diện.
- Chuyển chuồng, ghi cân nặng, theo dõi sức khỏe và đặt lịch chăm sóc.
- Bác sĩ thú y hoặc chủ xác nhận hoàn thành chăm sóc; nhân viên không có quyền xác nhận.
- Quản lý kho thức ăn, nhập/xuất, hủy giao dịch và cảnh báo tồn thấp.
- Bán vật nuôi liên kết phiếu thu; ghi thu chi, thống kê và biểu đồ doanh thu.
- Quản lý nhân sự, ảnh đại diện, sửa thông tin, khóa/mở khóa và xóa tài khoản theo quy tắc giữ lịch sử.
- Hiển thị thời tiết theo vị trí trang trại đã lưu.

Bốn vai trò: ADMIN (chủ trang trại), STAFF (nhân viên), VET (bác sĩ thú y), ACCOUNTANT (kế toán).

## Cấu trúc

```text
SmartFarm/
├── lib/                  Ứng dụng Flutter
├── test/                 Kiểm thử Flutter
├── android/, ios/, web/  Các nền tảng ứng dụng
├── windows/, linux/, macos/
├── config/online.json    Địa chỉ API online, không chứa khóa bí mật
├── backend/
│   ├── src/              API, nghiệp vụ, phân quyền và cấu trúc dữ liệu
│   ├── scripts/          Thiết lập, migration và khởi tạo dữ liệu
│   ├── support/          Hỗ trợ PostgreSQL cho phát triển và kiểm thử
│   ├── test/             Kiểm thử backend
│   ├── .env.example      Mẫu cấu hình, không phải thông tin truy cập thật
│   ├── package.json
│   └── package-lock.json
├── pubspec.yaml
├── pubspec.lock
└── render.yaml           Cấu hình triển khai API
```

Mở thư mục gốc chứa `pubspec.yaml` trong Android Studio hoặc VS Code.

## Yêu cầu môi trường

- Flutter có Dart 3.13.x hoặc phiên bản tương thích với `pubspec.yaml`. Mã nguồn được kiểm tra bằng Flutter 3.47.0 / Dart 3.13.0.
- Chrome để chạy Web; hoặc Android Studio, Android SDK và thiết bị/máy ảo để chạy Android.
- Nếu chạy hoặc kiểm thử backend: **Node.js 24 trở lên** và npm đi kèm. Kiểm tra bằng `node --version`; Node.js 10 không đáp ứng yêu cầu.

Android và Web là hai nền tảng trình diễn chính. Các runner khác được giữ theo cấu trúc Flutter, chưa xác nhận bản build native trên mọi nền tảng.

## Chạy nhanh bằng API online

Tại thư mục gốc sau khi clone:

```powershell
flutter pub get
flutter run -d chrome --web-port 8080 --dart-define-from-file=config/online.json
```

Để chạy Android, mở máy ảo hoặc kết nối điện thoại, sau đó:

```powershell
flutter devices
flutter run --dart-define-from-file=config/online.json
```

API được cấu hình trong `config/online.json`: `https://smart-farm-api-4n6x.onrender.com/api`.
Kiểm tra dịch vụ bằng cách mở địa chỉ API với hậu tố `/health`.
API và PostgreSQL online lần lượt được triển khai trên Render và Neon; chế độ này không cần bật backend/database trên máy cá nhân. Dịch vụ miễn phí có thể cần chờ khởi động sau khi không sử dụng.

**Tài khoản để kiểm tra:** chọn Đăng ký chủ trang trại, dùng email riêng, thiết lập loài rồi tạo tài khoản nhân viên, thú y và kế toán từ trang Nhân sự. Repository không chứa mật khẩu tài khoản hoặc dữ liệu riêng của chủ dự án.

Kịch bản kiểm tra: tạo khu vực → chuồng → giống → vật nuôi; ghi cân; lập và hoàn thành lịch bằng tài khoản thú y; nhập/xuất kho; bán vật nuôi bằng chủ; xem thu chi và doanh thu bằng chủ/kế toán. Dùng tài khoản nhân viên để kiểm tra thao tác bị giới hạn quyền.

## Chạy backend và database local

Cách này tạo database mới, độc lập với dữ liệu online. Không cần cài PostgreSQL riêng khi dùng tiến trình PostgreSQL phục vụ phát triển mà dự án cung cấp. Cần Internet để cài thư viện và tải thành phần phù hợp hệ điều hành.

Terminal thứ nhất, từ thư mục gốc:

```powershell
cd backend
npm ci
npm run setup:local
npm run db:start
```

Giữ terminal database mở. `setup:local` tạo `.env` với thông tin truy cập local ngẫu nhiên; không đưa file đó lên Git.

Terminal thứ hai, từ thư mục gốc:

```powershell
cd backend
npm run db:migrate
npm run dev
```

Migration tạo cấu trúc database. Sau đó dùng chức năng đăng ký trong app để tạo chủ và trang trại; không bắt buộc chạy seed. Nếu dùng PostgreSQL đã cài riêng, thay `DATABASE_URL` trong `.env` bằng database local của bạn và bỏ qua `db:start`.

Terminal thứ ba, chạy Web với backend local:

```powershell
flutter pub get
flutter run -d chrome --web-port 8080 --dart-define=API_URL=http://localhost:3000/api
```

Android Emulator dùng `--dart-define=API_URL=http://10.0.2.2:3000/api`. Điện thoại thật cần địa chỉ mạng của máy chạy API cùng cấu hình truy cập tương ứng. Dừng và chạy lại Flutter khi đổi địa chỉ API.

Thời tiết cần `WEATHER_API_KEY` của OpenWeather trong môi trường backend và vị trí trang trại do chủ lưu trong ứng dụng. Khóa này không nằm trong source; thiếu cấu hình thời tiết không ngăn các nghiệp vụ quản lý khác.

## Kiểm thử

Từ thư mục gốc:

```powershell
flutter pub get
flutter analyze
flutter test
```

Backend, dùng Node.js 24 trở lên:

```powershell
cd backend
npm ci
npm run typecheck
npm test
npm run build:cloud
```

Bộ kiểm thử backend dùng database kiểm thử tạm và phản hồi thời tiết giả lập; không cần kết nối Neon hoặc API key thật. Không build APK trong các lệnh kiểm tra trên.

## Triển khai backend

Nếu dùng toàn bộ repository này trên Render, đặt Root Directory là `backend`:

- Build Command: `npm ci --include=dev && npm run build:cloud`.
- Start Command: `npm run start:cloud`.
- Health Check: `/api/health`.
- Cấu hình `DATABASE_URL` cho PostgreSQL, `CORS_ORIGINS` cho origin Web, `WEATHER_API_KEY` nếu dùng thời tiết và Node.js 24+.

`start:cloud` chạy migration trước khi mở API. Không đưa `.env`, mật khẩu database hoặc khóa thời tiết vào Git. Nếu đổi URL API, cập nhật `config/online.json` rồi chạy/build lại Flutter. Dữ liệu runtime nằm trong PostgreSQL, không nằm trong repository.
