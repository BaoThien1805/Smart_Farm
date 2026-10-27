# Rà soát luồng và giao diện — 26/10/2026

Đã rà soát mã nguồn, chạy kiểm tra tự động và thao tác trên TECNO LJ6 với APK
online. Đã cài bản sửa cuối, khôi phục phiên chủ trại và để app ở Tổng quan.

## Đã sửa

1. **Mở form tải thừa danh sách vật nuôi.** Phần bổ sung icon chuồng trước đó
   chạy cả khi form chỉ cần danh mục, gây thêm lượt đọc và làm mở form chậm hơn.
   Giờ chỉ màn hình có hiển thị chuồng và Tổng quan yêu cầu dữ liệu nhận diện
   loài; các form, tìm kiếm và bộ lọc giữ nguyên phạm vi đọc. Thêm kiểm tra hồi quy.
2. **Thẻ số liệu Tổng quan lệch chiều cao.** Nhãn “Chuồng hoạt động” xuống hai
   dòng khiến thẻ cao hơn hai thẻ còn lại. Giờ ba thẻ dùng cùng chiều cao nhãn,
   tính theo cỡ chữ thực tế. Kiểm tra trên TECNO xác nhận cả ba cao 360 px.

## Kết quả kiểm tra

| Phạm vi | Kết quả |
| --- | --- |
| Toàn bộ Flutter | 583 bài đạt sau khi sửa lượt đọc thừa |
| Kiểm tra cuối cho thay đổi giao diện, điều hướng và icon | 31 bài đạt |
| Backend trên PostgreSQL tạm | 51 bài nghiệp vụ đạt; bài showcase phải chạy lại riêng sau lỗi kết nối database kiểm thử ở lượt đầu |
| Phân tích Dart | Không có issue |
| TypeScript thường và cloud | Kiểm tra kiểu thành công |
| Build/cài Android online | Thành công, cài đè giữ phiên và dữ liệu app |

Các kiểm tra tự động bao gồm đăng ký/đăng nhập/thu hồi phiên, phân quyền bốn vai
trò, cô lập trang trại, tạo/sửa hồ sơ, chuyển chuồng, cân, sức khỏe, lịch chăm sóc,
nhập/xuất/hủy kho, bán/hủy bán, liên kết thu chi, chống ghi trùng và cập nhật các
tab khi quay lại. Kiểm tra giao diện bao gồm màn hình hẹp và chữ lớn 1,3 lần.

Trên TECNO đã mở Tổng quan, Chuồng, Thêm, kho, lịch sử nhập/xuất, form nhập kho,
thu chi, báo cáo, giao dịch bán, nhân sự, danh mục loài/giống và tài khoản.
Form nhập kho báo đúng các trường bắt buộc khi để trống, nút Lưu nằm trên bàn
phím, và Hủy quay lại đúng trang. Bản cài cuối vẫn hiển thị đúng icon bò/cá.
Các màn đã quan sát không có lỗi tràn chữ, nút bị che hoặc thông báo lỗi kết nối.

Đối chiếu API sau kiểm tra vẫn có 56 vật nuôi, 26 chuồng, 53 lịch chăm sóc,
8 thức ăn, 14 phiếu kho, 4 giao dịch bán, 29 khoản thu chi và 6 tài khoản trong
trại demo chính. Không ghi giao dịch nghiệp vụ mới vào bộ demo online.

## Bằng chứng

- [Tổng quan sau sửa](../outputs/flow-ui-audit-20261026/final-overview.png)
- [Icon chuồng trên bản cài cuối](../outputs/flow-ui-audit-20261026/final-pens.png)
- [Form nhập kho và bàn phím](../outputs/flow-ui-audit-20261026/stock-keyboard.png)
- [Thu chi](../outputs/flow-ui-audit-20261026/finance.png)
- [Nhân sự](../outputs/flow-ui-audit-20261026/personnel.png)
- [Toàn bộ Flutter](../outputs/flow-ui-audit-20261026/flutter-tests-fixed.log)
- [Kiểm tra cuối](../outputs/flow-ui-audit-20261026/targeted-final-tests.log)
- [Backend lượt chính](../outputs/flow-ui-audit-20261026/backend-tests.log)
- [Backend showcase chạy lại](../outputs/flow-ui-audit-20261026/backend-showcase-retry.log)
- [Đối chiếu dữ liệu online](../outputs/flow-ui-audit-20261026/online-data-check.json)

## Giới hạn

Các thao tác ghi nghiệp vụ được kiểm tra trên database tạm qua API và widget;
trên điện thoại không xác nhận bán, hủy bán hoặc thay đổi kho thật để giữ bộ demo.
Chưa thử camera quét QR, lấy GPS, chọn ảnh và in/chia sẻ PDF qua ứng dụng bên
ngoài trong lượt này. Chưa đo hiệu năng của APK release hoặc kiểm tra thiết bị iOS.
Không ghi nhận thêm lỗi chặn luồng trong phạm vi đã kiểm tra.
