# Mugoat iOS v1.1.3 — Camera/Aim, nút Vào game và quản lý Mod

- Camera và aim dùng cùng chiều trục dọc mặc định: vuốt lên nhìn lên, vuốt xuống nhìn xuống. Tùy chọn **Invert Y** cho phép đảo chiều.
- Chuyển động vuốt được gửi một lần vào đường chuột của engine, tránh cộng thêm cùng chuyển động vào cần phải. Giữ phần chuyển động nhỏ hơn một pixel để giảm giật khi vuốt chậm.
- Bỏ chuyển động tồn đọng sau khung hình chậm trên 50 ms; xóa phần tích lũy khi tắt camera cảm ứng hoặc tạm ngừng điều khiển.
- Nút **Vào game** mở bước chọn dữ liệu/chế độ khi còn thiếu điều kiện. Lỗi mở thư mục dữ liệu không còn làm ứng dụng kẹt ở trạng thái đã chạy game.
- Quản lý Mod lọc theo định dạng: file hướng dẫn `.txt` không được liệt kê hoặc nhập như mod. Báo lỗi khi không nhập/giải nén được thay vì báo thành công.
- Bỏ hướng dẫn cài xe Mercedes trong Quản lý Mod.

Kiểm tra tự động bao gồm chiều camera/aim, tùy chọn đảo trục, chuyển động nhỏ, 30/60/120 Hz, giữ ngón tay đứng yên, khung hình chậm và lọc file mod. Độ mượt khi chơi thực tế vẫn cần kiểm tra trên iPhone; bản sửa không bảo đảm hết mọi hiện tượng tụt FPS hoặc giật do tải tài nguyên.

**Phạm vi Quản lý Mod:** nhập/giải nén, lọc danh sách và đổi tên file `.disabled` để quản lý tệp. Việc nạp DLC/xe trong gameplay chưa được xác minh. Các mục Drift, tốc độ, vô hạn đạn, No Recoil và trọng lực hiện là giao diện chưa kết nối engine; thông báo kích hoạt của chúng không chứng minh hiệu ứng trong game. Chưa có bộ nạp Lua/ASI hoặc trình vá RPF hoàn chỉnh.

**Mugoat.ipa**: gói Apple ID Free, iOS 16.0+, cần ký bằng công cụ cài IPA phù hợp. **Mugoat-Cert-Paid.ipa** dùng quyền bộ nhớ mở rộng nếu chứng chỉ/provisioning profile cho phép.
