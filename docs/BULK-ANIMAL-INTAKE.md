# Nhập vật nuôi theo số lượng

Trong **Thêm vật nuôi**, chọn **Theo số lượng**, nhập số con (1–1.000), chọn loài, giống và chuồng. Các thông tin giới tính, ngày sinh, ngày nhập, nguồn gốc, tên chung, ghi chú và ảnh áp dụng cho cả đợt. Mỗi con vẫn có hồ sơ riêng để cân, chăm sóc, chuyển chuồng hoặc bán về sau.

Mã đầu tiên cần có đuôi số, ví dụ `GA-001`. Nhập 30 con tạo dãy `GA-001` đến `GA-030`; có thể xem trước và chỉnh mã đầu tiên trước khi lưu. Dãy mã giữ số 0 ở đầu, tối đa 12 chữ số và 100 ký tự mỗi mã.

Form hiển thị số chỗ còn lại và tổng đàn trong chuồng sau khi nhập. Máy chủ kiểm tra lại sức chứa trong giao dịch có khóa, kể cả khi hai người cùng nhập. Trùng bất kỳ mã nào, chuồng không đủ chỗ, giống không hợp lệ hoặc lỗi giữa chừng đều hủy cả đợt. Không tự tạo khoản chi.

API mới: `POST /api/animals/batch/create`, dành cho ADMIN và STAFF. Nhận các trường của thêm một con, thay `code` bằng `firstCode`, thêm `quantity` và `requestId` UUID. Trả `count`, `animals` (id/code), `firstCode`, `lastCode`. Gửi lại cùng yêu cầu không tạo thêm hồ sơ; cùng requestId với nội dung khác trả 409. VET và ACCOUNTANT không được nhập đàn.

Phải triển khai backend có API này trước khi dùng chức năng trên bản Android online. Build Android cài song song bằng `flutter build apk --release --flavor preview --target-platform android-arm64 --dart-define-from-file=config/online.json` để ứng dụng dùng Internet, không phụ thuộc USB. Dữ liệu local và online độc lập.

Bản `preview` có tên **Smart Farm Mới**, package `vn.edu.smartfarm.smart_farm.preview`, cài song song với **Smart Farm** (`vn.edu.smartfarm.smart_farm`). Bản `standard` mặc định giữ package cũ. Hai ứng dụng có phiên đăng nhập và bộ nhớ thiết bị riêng; khi đăng nhập cùng tài khoản online, hai bản dùng chung dữ liệu máy chủ. Giữ app cũ là dự phòng phiên bản, không tạo bản sao dữ liệu online.

Kiểm thử nằm trong `test/animal_editor_redesign_test.dart` và `backend/test/farm.test.ts`, dùng HTTP giả lập hoặc PostgreSQL tách biệt; không nhập thêm vật nuôi vào trại demo thật.

## Chạy bản mới local qua USB

Sau khi đã cài bản preview, dùng `./Start-Demo.ps1 -Preview` để bật API local, nối cổng USB và mở **Smart Farm Mới**. Cổng 3000 và cổng thực tế của backend (hiện là 3001) đều được nối qua USB. Không reset dữ liệu demo khi chạy lại.

Lệnh build và chạy bản local: `flutter run -d 838d71ed --flavor preview --debug --no-pub --dart-define=API_URL=http://127.0.0.1:3001/api` (thay ID nếu dùng điện thoại khác). Giữ máy tính, backend và cáp USB kết nối trong lúc test. Bản local này dùng dữ liệu local; phiên và dữ liệu online của app cũ giữ riêng.
