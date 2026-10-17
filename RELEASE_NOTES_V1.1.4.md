# Mugoat iOS v1.1.4 — Hồi sinh Bệnh viện, Thoát xe kẹt/nổ, Nhảy dù Trực thăng, Sửa văng độ phân giải cao & DLC Spawner

Bản cập nhật **v1.1.4** khắc phục triệt để các lỗi gameplay cốt lõi, nâng cấp hệ thống điều khiển và trình quản lý xe mod:

---

### 🌟 Các cải tiến và sửa lỗi chính trong bản v1.1.4:

1. **🚁 Nhảy dù & Thoát khẩn cấp khỏi trực thăng / máy bay:**
   - Khắc phục lỗi không thể nhảy ra hoặc rơi tự do khi lái trực thăng / máy bay.
   - Khi bấm nút thoát buồng lái (`Enter/F`), game tự động trang bị dù cứu sinh (`GADGET_PARACHUTE`) và thực hiện thao tác Bailout + Jumpout (`4096 | 256`) giúp nhân vật bung ra ngoài an toàn.

2. **🚗 Thoát xe khi bị kẹt hoặc nổ (Warp Exit):**
   - Giải quyết triệt để vấn đề nhân vật bị kẹt cứng trong xe khi xe bị biến dạng, lật úp, kẹt góc hoặc bốc cháy nổ.
   - Kích hoạt lệnh thoát khẩn cấp với cờ Warp-out (`16`), lập tức đưa nhân vật ra vị trí an toàn cạnh xe mà không phụ thuộc vào hoạt cảnh mở cửa.

3. **🏥 Hệ thống Hồi sinh tại Bệnh viện khi chết (Hospital Respawn):**
   - Nhân vật khi cạn máu không còn bị kẹt vĩnh viễn ở trạng thái ragdoll trên mặt đất.
   - Tự động tìm và chuyển người chơi về 1 trong 5 bệnh viện gần nhất (Pillbox Hill, Mount Zonah, Central Los Santos, Sandy Shores, Paleto Bay), xóa bỏ ragdoll, hồi đầy máu và trả lại quyền điều khiển.

4. **🛑 Đứng im khi nhập mã lệnh Cheat (Cheat Freeze):**
   - Khóa toàn bộ input di chuyển, đấm đá, cướp xe khi đang mở bàn phím gõ cheat. Nhân vật sẽ đứng yên tuyệt đối để bạn nhập mã mượt mà như Muguet.

5. **🗺️ Chấm điểm bản đồ (Waypoint):**
   - Khắc phục thao tác đánh dấu điểm đến trên bản đồ. Nâng ngưỡng rê cảm ứng lên 14 pt và gửi đồng thời tap + double-click + Enter + Gamepad A giúp chấm map chính xác ngay trên màn hình cảm ứng.

6. **🖥️ Sửa lỗi văng game (Crash / Out) khi chỉnh độ phân giải cao:**
   - Ngăn chặn triệt để lỗi tràn VRAM và lỗi Metal Shader Trap: Khóa cố định `shaderQuality = 1` và giới hạn render an toàn ở mức **2560 × 1080** (tương đương chuẩn Muguet).
   - Tự động nạp sẵn cấu hình `settings.xml` an toàn trước khi chạy engine, tắt các hiệu ứng nặng gây crash trên iOS (MSAA, TXAA, Tessellation, DoF).

7. **📦 Quản lý Mod & Triệu hồi Xe Mod (DLC Vehicle Spawner):**
   - Cơ chế nạp mod hoàn toàn chạy qua overlay ảo trong RAM/cache (`manifest.json`), **bảo toàn 100% file game gốc** (chấm dứt lỗi tệp bất thường).
   - Tự động nhận diện các gói Add-on DLC (như `mbs1k`) và hiển thị trực tiếp trong mục **Gọi phương tiện & Xe Mod** để spawn và tự động nhảy vào ghế lái.
   - Hỗ trợ nhập tên model bất kỳ để spawn xe theo ý muốn.

---

### 📦 Tệp cài đặt:
- **`Mugoat.ipa`**: Bản IPA chuẩn (Apple ID Free), hỗ trợ iOS 15.0+ (iOS 15, iOS 16, iOS 17, iOS 18+ — hỗ trợ từ iPhone 6s/7/8/X trở lên), tương thích mọi công cụ ký (TrollStore, ESign, Scarlet, AltStore, SideStore, Sideloadly).
- **`Mugoat-Cert-Paid.ipa`**: Bản mở rộng bộ nhớ dành cho chứng chỉ nhà phát triển (Paid Developer Certificate).
