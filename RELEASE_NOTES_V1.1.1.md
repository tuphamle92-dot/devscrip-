# Mugoat iOS v1.1.1 — Bản cập nhật Điều khiển, Camera Mượt mà & Trình Quản lý Mod (iOS 16.0+)

**Mugoat v1.1.1** tập trung hoàn thiện trải nghiệm gameplay, chuyển động camera siêu mượt mà không rung giật, sửa lỗi ngược góc nhìn và bổ sung Trình Quản lý Mod độc lập dựa trên phản hồi của cộng đồng iOSVN.

---

### 🌟 Các cải tiến & sửa lỗi nổi bật:

1. **Khắc phục triệt để lỗi ngược trục dọc Camera & Ngắm bắn (Aim):**
   - Đã sửa lỗi kéo ngón tay xuống thì camera nhìn lên, kéo lên thì camera nhìn xuống. Góc nhìn camera giờ đây di chuyển đúng 100% theo hướng ngón tay vuốt.
   - Bổ sung tùy chọn **"Đảo ngược trục dọc (Invert Y)"** trong Cài đặt điều khiển cho người chơi quen phong cách lái máy bay.

2. **Chấm dứt hoàn toàn hiện tượng rung giật (Jitter / Stutter) khi xoay Camera:**
   - Loại bỏ xung đột ngầm giữa bộ giả lập cần gạt Gamepad (Right Stick) và bộ đọc chuột (Mouse Delta).
   - Tích hợp bộ tích lũy sub-pixel delta chuột siêu mượt (tương tự cơ chế Muguet), xoay góc nhìn và ngắm bắn mượt mà 60/120 FPS như PC.

3. **Trình Quản lý Mod (Mod Manager) độc lập & mượt mà:**
   - Khắc phục lỗi bấm vào mục Mod không có phản hồi bằng cơ chế chuyển trang `pushViewController` chuẩn UIKit.
   - Tự động tạo thư mục `mods` tại: `Tệp › Trên iPhone › Mugoat › mods`.
   - Bổ sung nút **"Nhập Mod từ tệp"** hỗ trợ nạp các file mod (`.zip`, `.rpf`, `.meta`, `.asi`) trực tiếp từ ứng dụng Tệp hoặc iCloud.
   - Quản lý danh sách mod: Bật / Tắt riêng từng mod (`.disabled`) hoặc xóa mod ngay trên điện thoại.
   - Tích hợp sẵn các tùy biến vật lý game (Mod xe siêu tốc, chế độ Drift, vô hạn đạn, khóa giật súng, trọng lực Mặt Trăng).

4. **Nút ngắm bên trái (Left Aim) trong Bố cục điều khiển:**
   - Bổ sung nút ngắm phụ bên tay trái (`leftAim`) trong trình chỉnh sửa bố cục (`ControlsLayoutEditorController`).
   - Tự do di chuyển, phóng to/thu nhỏ, bật/tắt nút ngắm bên trái để thuận tiện vừa di chuyển vừa ngắm bắn 3-4 ngón tay.

5. **Cảm ứng Bản đồ thông minh (Map Touch & Pinch-to-Zoom):**
   - Hỗ trợ vuốt 1 ngón tay để kéo bản đồ Los Santos linh hoạt như Google Maps.
   - Chạm nhanh để chọn menu hoặc đánh dấu điểm đến (Waypoint / GPS).
   - Thu phóng bản đồ bằng 2 ngón tay (Pinch to zoom) mượt mà.

---

### 📦 Tải bản cài đặt:
* **`Mugoat.ipa`** (85.7 MB): Bản cài đặt tiêu chuẩn hợp nhất cho mọi thiết bị iOS 16.0+ (TrollStore, ESign, Scarlet, AltStore, Sideloadly).
