# Luồng test thủ công CINE-X

File này dùng để tự test app sau khi seed data mới được thêm. Ưu tiên chạy trên Windows desktop hoặc Android emulator vì `main.dart` hiện chưa hỗ trợ Flutter Web.

## 0. Chuẩn bị dữ liệu

Nếu test backend online từ database sạch:

```powershell
cd "D:\1_PRM393_Hoc lieu\PRM393_SE1901_G6\cine-x"
docker compose down -v
docker compose up -d postgres
cd backend
mvn spring-boot:run
```

Nếu test app local/offline:

```powershell
cd "D:\1_PRM393_Hoc lieu\PRM393_SE1901_G6\cine-x\frontend"
flutter run -d windows
```

Tài khoản seed, tất cả dùng mật khẩu `CineX@123`:

```text
owner@cinex.local
writer@cinex.local
producer@cinex.local
ad@cinex.local
viewer@cinex.local
```

Dữ liệu seed chính:

```text
Dự án: Người Giữ Ánh Sáng / Nguoi Giu Anh Sang
Hồi: 3
Cảnh: 8
Nhân vật: Linh, Minh, Đám đông nhà ga, Bao, Huyen, To an ninh
Bối cảnh truyện: Phòng điều khiển ngầm, Sân ga trên cao, Cho dem duoi long dat, Mai nha vien thong, Ham bao tri so 7
Địa điểm quay: Studio A, Bãi dựng Sky Station, Set cho dem Zone B, Rooftop vien thong mockup
Tài nguyên: Máy quay A, Bộ đèn LED thực tế, Flycam Mini, Ao khoac phan quang, Hop thiet bi cu, Xe van san xuat
Ngày quay seed: 2026-07-15 và 2026-07-16
```

## 1. Đăng nhập và chế độ offline

Màn hình: `AuthScreen`.

Test đăng nhập đúng:

```text
Địa chỉ email: owner@cinex.local
Mật khẩu: CineX@123
```

Bấm `Đăng nhập`. Kết quả mong đợi: vào màn `Studio CINE-X`, thấy project seed.

Test đăng nhập sai:

```text
Địa chỉ email: owner@cinex.local
Mật khẩu: wrong-password
```

Bấm `Đăng nhập`. Kết quả mong đợi: hiện lỗi email hoặc mật khẩu.

Test offline: từ màn login bấm `Dùng ngoại tuyến`. Kết quả mong đợi: vẫn vào màn danh sách dự án local và thấy project seed.

## 2. Danh sách dự án và tìm kiếm

Màn hình: `ProjectLauncherScreen`.

Ô tìm kiếm, copy lần lượt:

```text
CINE-X
```

Kết quả mong đợi: vẫn thấy project seed vì description có CINE-X.

```text
khong-co-du-an-999
```

Kết quả mong đợi: danh sách rỗng hoặc không còn project nào khớp. Xóa ô tìm kiếm và bấm icon mũi tên để tải lại toàn bộ.

## 3. Tạo dự án mới

Màn hình: `ProjectLauncherScreen` -> bấm nút `Dự án mới`.

Copy dữ liệu:

```text
Tiêu đề dự án: Bai Test Manual - Canh Cua Bien
Thể loại: Mystery drama
URL poster: https://picsum.photos/seed/cinex-manual/800/1200
Logline hoặc ghi chú sản xuất: Dự án dùng để test luồng tạo mới, chỉnh sửa và lên lịch.
Ngày bắt đầu: chọn 2026-07-20
Ngày kết thúc: chọn 2026-08-05
Số phút quay tối đa mỗi ngày: 420
```

Bấm `Tạo dự án`. Kết quả mong đợi: project mới xuất hiện ở danh sách.

Negative test: mở lại `Dự án mới`, nhập `Số phút quay tối đa mỗi ngày` là `0`. Kết quả mong đợi: form báo lỗi và không tạo dự án.

## 4. Kiểm tra dữ liệu seed trong workspace

Màn hình: mở project `Người Giữ Ánh Sáng`.

Tab `Kịch bản`: kiểm tra có 3 hồi và 8 cảnh. Cảnh seed quan trọng:

```text
Cảnh 2 - Đường ray mất điện: sẵn sàng lên lịch, dùng Máy quay A x1.
Cảnh 3 - Cửa sổ bị khóa: chưa sẵn sàng vì chưa gán địa điểm quay.
Cảnh 6 - Diem hen tren mai nha: đã lên lịch ngày 2026-07-16.
Cảnh 7 - Phong sang thuc tinh: đã quay.
```

Tab `Phân tích`: kiểm tra tổng cảnh, tiến độ và biểu đồ nhân vật có dữ liệu.

## 5. Tạo hồi mới và test trùng thứ tự

Màn hình: project seed -> tab `Kịch bản` -> icon `Tạo hồi`.

Happy path:

```text
Tiêu đề hồi: Hoi 4 - Test bo sung
Thứ tự: 4
Mô tả: Hoi dung cho manual test.
```

Bấm `Lưu`. Kết quả mong đợi: hồi 4 xuất hiện.

Negative test:

```text
Tiêu đề hồi: Hoi trung thu tu
Thứ tự: 1
Mô tả: Test duplicate order.
```

Bấm `Lưu`. Kết quả mong đợi: báo lỗi thứ tự đã tồn tại.

## 6. Tạo tài nguyên sản xuất

Màn hình: tab `Tài nguyên`.

Tab con `Nhân vật` -> bấm thêm nhân vật:

```text
Tên: Mai Test
Vai trò: Vai phụ
Tâm lý: Nhanh nhạy, hay nghi ngờ nhưng trung thành với nhóm.
Ngoại hình: Áo khoác xanh, tóc ngắn, luôn mang bộ đàm.
```

Tab con `Bối cảnh truyện` -> bấm thêm:

```text
Tên: Can cau so 9
Mô tả: Cầu cũ cạnh bến cảng, gió mạnh.
Ghi chú: Dùng cho cảnh test ngoại cảnh đêm.
```

Tab con `Địa điểm quay` -> bấm thêm:

```text
Tên: Kho hang test
Địa chỉ: 12 Test Manual, Thu Duc
Thành phố: TP Ho Chi Minh
Quận/huyện: Thu Duc
Vĩ độ: 10.8021
Kinh độ: 106.7145
Người liên hệ: Chi Linh
Số điện thoại liên hệ: 0912345678
Có thể dùng từ HH:mm: 07:30
Có thể dùng đến HH:mm: 18:00
Ghi chú: Dia diem dung cho manual test.
```

Negative test địa điểm: nhập `Vĩ độ` là `999`, kết quả mong đợi là form báo lỗi tọa độ.

Tab con `Tài nguyên` -> bấm thêm:

```text
Tên: Boom mic test
Loại: Thiết bị
Số lượng: 2
Đơn vị: bo
Trạng thái: Sẵn sàng
Ghi chú: Dung de test gan tai nguyen vao canh.
```

Negative test tài nguyên: nhập `Số lượng` là `0`, kết quả mong đợi là form báo lỗi.

## 7. Tạo cảnh mới

Màn hình: tab `Kịch bản` -> icon `Tạo cảnh`.

Happy path:

```text
Số cảnh: 9
Tiêu đề: Thu nghiem canh moi
Tóm tắt: Mai Test gap Linh tai can cau so 9 de trao doi thiet bi.
Hồi: chọn Hồi 3 - Ánh sáng hoặc Hoi 4 - Test bo sung nếu đã tạo
Bối cảnh truyện: Can cau so 9
Địa điểm quay thực tế: Kho hang test
Bối cảnh: Ngoại cảnh
Thời điểm: Đêm
Số phút ước tính: 6
Trạng thái viết: Cần viết
Trạng thái sản xuất: Sẵn sàng lên lịch
Ưu tiên: 3
Nhân vật: chọn Linh và Mai Test
Tài nguyên: chọn Boom mic test, Số lượng cần dùng: 1
```

Bấm `Lưu cảnh`. Kết quả mong đợi: cảnh 9 xuất hiện trong bảng cảnh và trong danh sách cảnh sẵn sàng chưa lên lịch.

Negative test trùng số cảnh:

```text
Số cảnh: 1
Tiêu đề: Trung so canh
Tóm tắt: Test duplicate scene number.
```

Kết quả mong đợi: báo lỗi số cảnh đã tồn tại.

Negative test sai loại địa điểm: tạo cảnh `Nội cảnh`, chọn `Bãi dựng Sky Station` làm địa điểm quay thực tế. Kết quả mong đợi: báo lỗi địa điểm không hỗ trợ cảnh nội cảnh.

## 8. Lịch quay

Màn hình: tab `Lịch quay`.

Kiểm tra seed:

```text
Chọn ngày 2026-07-15: thấy "Ngay quay 01 - Studio", có cảnh 1 và cảnh 7 với giờ 08:00-08:08, 08:20-08:31.
Chọn ngày 2026-07-16: thấy "Ngay quay 02 - Ngoai canh", có cảnh 6 với giờ 17:30-17:39.
```

Tạo ngày quay mới:

```text
Tiêu đề: Ngay quay test - Manual
Số phút tối đa: 60
Ngày: chọn 2026-07-23
Ghi chú: Dung de test them canh vao lich.
```

Bấm `Lưu`. Kết quả mong đợi: ngày quay mới xuất hiện trên calendar.

Thêm cảnh vào lịch:

1. Chọn ngày `2026-07-23`.
2. Ở phần `Cảnh sẵn sàng chưa lên lịch`, bấm icon `+` ở cảnh 9 hoặc cảnh 4.
3. Trong sheet `Xếp cảnh vào lịch`, copy:

```text
Bắt đầu (HH:mm): 09:00
Kết thúc (HH:mm): 09:06
```

Bấm `Thêm vào lịch`. Kết quả mong đợi: cảnh được chuyển vào ngày quay và status cảnh thành `Đã lên lịch`.

Negative test giờ quay:

```text
Bắt đầu (HH:mm): 11:00
Kết thúc (HH:mm): 10:30
```

Kết quả mong đợi: form báo lỗi giờ kết thúc phải sau giờ bắt đầu.

Negative test tài nguyên vượt số lượng:

1. Chọn ngày `2026-07-15`.
2. Ở phần `Cảnh sẵn sàng chưa lên lịch`, bấm `+` ở cảnh 2 `Đường ray mất điện`.
3. Giữ giờ gợi ý hoặc nhập:

```text
Bắt đầu (HH:mm): 08:40
Kết thúc (HH:mm): 08:52
```

Kết quả mong đợi: không thêm được vì ngày 2026-07-15 đã có cảnh 1 dùng `Máy quay A x1`, trong khi tổng kho chỉ có 1 máy.

## 9. Xuất PDF

Màn hình: trong workspace, bấm icon `Xuất PDF` ở header hoặc vào tab `Phân tích` rồi bấm FAB `Xuất PDF`.

Kết quả mong đợi: app mở preview/in PDF, nội dung có project, dashboard, cảnh, nhân vật, bối cảnh và tài nguyên.

## 10. Đồng bộ

Màn hình: `ProjectLauncherScreen` -> icon `Đồng bộ`.

Nếu đang dùng offline guest: kiểm tra màn sync không crash và hiển thị trạng thái local.

Nếu đang dùng online account và có backend: tạo mới project/cảnh/tài nguyên, sau đó mở `Đồng bộ` để kiểm tra queue pending và thao tác sync.
