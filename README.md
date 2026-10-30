# Smart Farm

Ứng dụng quản lý trang trại, gồm Flutter và REST API sử dụng Node.js, TypeScript, Fastify và PostgreSQL.

## Chức năng

- Đăng ký chủ trang trại, đăng nhập, đăng xuất và phân quyền ADMIN, STAFF, VET, ACCOUNTANT.
- Quản lý nhân sự, danh mục loài và giống, khu vực, chuồng trại.
- Quản lý vật nuôi, ảnh đại diện, cân nặng, chuyển chuồng, sức khỏe và lịch sử.
- Nhập đàn theo số lượng, tra cứu hồ sơ bằng QR và xuất thẻ QR dạng PDF.
- Lập lịch chăm sóc, lọc ngày, chọn nhiều lịch để hoàn thành hoặc hủy theo quyền.
- Quản lý kho thức ăn, nhập xuất, cảnh báo tồn thấp và liên kết chi phí nhập kho với sổ thu chi.
- Bán vật nuôi, ghi nhận thu chi, biểu đồ và thống kê doanh thu.
- Hiển thị thời tiết theo vị trí trang trại.

## Cấu trúc

- `lib/`: ứng dụng Flutter.
- `assets/`: hình ảnh, phông chữ và giấy phép tài nguyên.
- `backend/src/`: API và xử lý nghiệp vụ.
- `backend/scripts/`: khởi tạo, migration và dữ liệu mẫu.
- `test/`, `backend/test/`: kiểm thử Flutter và backend.
- `config/`: cấu hình địa chỉ API cho ứng dụng.
- `android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/`: cấu hình nền tảng.

Backend dùng biến môi trường; cấu hình mẫu nằm trong `backend/.env.example`.
