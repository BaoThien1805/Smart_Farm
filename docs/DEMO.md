# Trang trại Mầm Xanh · DEMO

Bộ dữ liệu dành cho kiểm thử và trình diễn đồ án, có bản local và bản online. Không phải dữ liệu chăn nuôi thực tế. Nằm trong trang trại riêng; không trộn với trại kiểm thử TECNO hoặc dữ liệu cũ.

## Mở demo online

Dùng APK build với `config/online.json`, đăng nhập các tài khoản ở bảng bên dưới.
Tài khoản chủ là `chutrai@demo.smartfarm.local`, mật khẩu ban đầu
`SmartFarmDemo@2026`. Bản online truy cập API
`https://smart-farm-api-4n6x.onrender.com/api`, không phụ thuộc máy tính hoặc USB.

Bộ demo online được tạo lại qua các API đăng ký, nhân sự và nghiệp vụ của ứng dụng,
gồm cả trại đối chứng riêng. ID hồ sơ và thời điểm tạo trên online là mới; ngày
nghiệp vụ, số lượng, ảnh, vai trò và lịch sử demo được tạo theo bản local.
Hai bản có dữ liệu độc lập: thao tác thêm/sửa trên một bản không tự đồng bộ sang bản kia.

## Mở demo local

Từ PowerShell tại thư mục dự án:

```powershell
.\Start-Demo.ps1
```

Lệnh build backend, bật PostgreSQL local nếu cần, tạo demo lần đầu, giữ nguyên dữ liệu demo ở các lần sau, bật API nếu chưa chạy và nối điện thoại USB tới API. Có thể dùng `-NoPhone` khi chỉ cần backend. Phần nối USB dành cho APK build với `--dart-define=API_URL=http://127.0.0.1:3000/api`; script nối địa chỉ đó tới cổng backend đã chọn. APK online vẫn dùng server online khi chạy script này.

Nếu đang đăng nhập `android@test.local`, hãy đăng xuất rồi đăng nhập tài khoản demo dưới đây. Máy tính/backend và USB phải tiếp tục kết nối khi dùng APK local này. Khi chuyển sang APK online, đăng nhập lại để nhận phiên của server online.

## Tài khoản

Mật khẩu ban đầu cho toàn bộ tài khoản dưới đây: **`SmartFarmDemo@2026`**.

| Email | Vai trò / mục đích |
| --- | --- |
| `chutrai@demo.smartfarm.local` | Chủ trang trại — toàn quyền |
| `nhanvien@demo.smartfarm.local` | Nhân viên — vật nuôi, cân/chuyển, quan sát sức khỏe, đặt lịch, nhập/xuất kho |
| `thuy@demo.smartfarm.local` | Bác sĩ thú y — khám và hoàn thành chăm sóc; xem kho |
| `ketoan@demo.smartfarm.local` | Kế toán — sổ thu chi, báo cáo, xem lịch sử bán; không được bán/hủy bán |
| `bikhoa@demo.smartfarm.local` | Tài khoản bị khóa — thử từ chối đăng nhập, chủ có thể mở khóa |
| `thuxoa@demo.smartfarm.local` | Nhân viên chưa có lịch sử — dùng thử sửa/khóa/xóa tài khoản |
| `doichieu@demo.smartfarm.local` | Chủ của trại khác — chỉ thấy trại đối chứng với `DC-001` |

Các vai trò đều do backend kiểm tra. STAFF không được xác nhận hoàn thành chăm sóc; VET không quản lý nhân sự hoặc ghi kho/thu chi; ACCOUNTANT không thao tác bán/hủy bán hay ghi dữ liệu vận hành. Chỉ chủ quản lý nhân sự, danh mục, kết thúc nuôi và hủy phiếu kho.

## Dữ liệu ban đầu

| Nhóm | Dữ liệu sẵn có |
| --- | --- |
| Loài / giống | 12 loài: Bò, Trâu, Heo, Dê, Cừu, Gà, Vịt, Ngan, Ngỗng, Cá, Tôm, Thỏ; 24 giống |
| Khu vực / chuồng | 4 khu vực, 26 chuồng/khu nuôi; có chuồng đầy, còn chỗ, trống và ngừng sử dụng |
| Vật nuôi | 56 hồ sơ: 51 đang nuôi, 3 đã bán, 2 đã chết; ảnh minh họa cho bò/heo/dê/gà |
| Cân và lịch sử | 220 bản ghi cân, chuyển chuồng, quan sát và khám có người thực hiện; `TH-004` chưa có lịch sử để thử xóa |
| Lịch chăm sóc | 12 lịch quá hạn, 12 hôm nay, 12 sắp tới; 11 hoàn thành và 6 đã hủy |
| Kho | 8 thức ăn, có tồn thấp/hết tồn/chưa nhập/ngừng sử dụng; phiếu nhập/xuất hợp lệ và đã hủy |
| Thu chi / bán | Thu chi của 6 tháng gần nhất, audit tạo/sửa/hủy; 3 bán hợp lệ, 1 bán đã hủy và cá thể đã nhận lại |
| Thời tiết | Tọa độ tham chiếu công khai tại Đà Lạt, thời tiết thật qua API; không dùng GPS cá nhân |
| Cô lập dữ liệu | Một trại đối chứng riêng, chỉ có `DC-001` |

Ngày trong dữ liệu được tính từ ngày chạy lần đầu. Chạy lại seed không đổi lịch, mật khẩu hoặc các thao tác đã làm trong buổi demo.

## Kịch bản trình diễn 10–15 phút

1. **Chủ trang trại:** mở Tổng quan; xem số con, lịch hôm nay/quá hạn, cảnh báo thức ăn và thời tiết. Mở chuồng `BO-C1` đầy 4/4, so với `BO-C2` còn chỗ và `CL-01` trống.
2. **Hồ sơ:** tìm `BO-001`, xem ảnh, 4 lần cân, lịch sử chuyển và khám; lọc loài/trạng thái. `BO-002` cần chăm sóc. `TH-004` dành cho thử xóa hồ sơ chưa phát sinh lịch sử.
3. **Nhân viên:** đăng nhập STAFF; ghi cân hôm nay, chuyển `BO-001` sang `BO-C2`, đặt lịch chăm sóc. Quan sát không có quyền xác nhận hoàn thành hoặc quản lý nhân sự/thu chi.
4. **Bác sĩ thú y:** đăng nhập VET; mở lịch hôm nay của `BO-002`, xác nhận hoàn thành; xem kết quả ở hồ sơ sức khỏe. Không dùng nội dung mô phỏng để hướng dẫn điều trị thật.
5. **Kho:** với STAFF hoặc chủ, `TA-01` đang tồn thấp; nhập 20 kg cho `TA-02`, xuất 5 kg, xem lịch sử. Chủ hủy phiếu xuất với lý do; tồn tăng lại, dấu hủy và người thực hiện còn giữ.
6. **Bán/hủy bán:** chủ bán `GA-004`, kiểm tra con rời danh sách Đang nuôi và khoản thu được tạo một lần. Vào Giao dịch bán, hủy với lý do và nhận lại vào `GA-C2`; con trở về ACTIVE, khoản thu hủy, lịch cũ đã hủy không tự phục hồi.
7. **Kế toán:** ghi khoản chi FEED, sửa với lý do, mở audit trước/sau. Lọc báo cáo từ đầu tháng cách đây 5 tháng tới hôm nay để xem đủ 6 tháng; doanh thu bán nằm trong Tổng thu, chênh lệch thu chi không phải lợi nhuận kế toán.
8. **Nhân sự / cô lập:** chủ mở khóa `bikhoa`, sửa/khóa/xóa tài khoản `thuxoa`. Đăng nhập chủ đối chứng chỉ thấy `DC-001`, không thấy đàn Mầm Xanh.

## Demo QR vật nuôi

1. Mở **Đàn vật nuôi → hồ sơ một con → Thẻ QR**. Mỗi con có một mã riêng theo ID; đổi tên, mã hiển thị hoặc chuyển chuồng vẫn dùng được QR đã in.
2. Chọn **Lưu / chia sẻ PDF** để gửi thẻ sang máy khác; hoặc **In thẻ QR**, chọn máy in hay **Lưu dưới dạng PDF** của Android. Thẻ khổ A6 có chữ tiếng Việt và QR đen trên nền trắng. Thông tin tên/mã in trên giấy là tại lúc xuất; xuất lại nếu muốn cập nhật phần chữ.
3. Vào **Đàn vật nuôi → Quét QR** hoặc **Thêm → Quét QR vật nuôi**, cấp quyền camera khi Android hỏi. Quét mã trên một màn hình khác hoặc trên giấy để mở thẳng hồ sơ, không cần chọn chuồng.
4. Có thể **Chọn ảnh QR** trên Android/iOS/macOS hoặc **Dán nội dung QR** khi không dùng được camera. Nút sao chép nằm trong trang Thẻ QR. Ảnh PNG/JPEG tối đa 12 MB.
5. Thử lại bằng tài khoản nhân viên, thú y, kế toán: quyền thao tác trong hồ sơ giữ nguyên. Quét QR của trại khác hoặc con đã xóa sẽ báo không tìm thấy. Con đã bán/chết vẫn có hồ sơ và QR, các thao tác nuôi bị khóa như trước.

QR theo định dạng `smartfarm://animal/v1/<uuid>`, chỉ chứa ID, không chứa mật khẩu, token hoặc thông tin hồ sơ. Dùng trình quét **trong Smart Farm**; chưa đăng ký mở ứng dụng từ camera mặc định của điện thoại. Cần đăng nhập và kết nối backend để xem hồ sơ. Camera hỗ trợ Android, iOS, macOS và web; Windows/Linux dùng dán mã. Với APK local cần tiếp tục chạy `Start-Demo.ps1` và giữ USB/backend kết nối.

## Chạy seed riêng

```powershell
cd backend
npm run db:seed:showcase
```

CLI chỉ cho phép môi trường development/test và database loopback. Dùng `.env` của backend; nếu có `.local/demo.env` thì file này chọn DB/port demo riêng. File cấu hình local chứa thông tin kết nối và đã được Git bỏ qua. Seed chạy trong transaction, giữ dữ liệu cũ và có thể chạy lại không nhân đôi.
