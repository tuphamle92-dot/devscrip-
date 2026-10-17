# Mugoat iOS v1.1.0 — Native C/Metal Hybrid Edition (iOS 16.0+)

**Mugoat v1.1.0** là phiên bản tái cấu trúc hoàn chỉnh dựa trên nền tảng **Native C/Metal thuần túy** của GTA V Port, kết hợp cùng cầu nối mạng đa người chơi **Native Online Bridge** kết nối trực tiếp máy chủ AWS Singapore.

---

### 🌟 Kiến trúc & Cải tiến đột phá:

- **100% Native C & Apple Metal (ARM64 Mach-O):**
  - Sử dụng `wasm2c-native` chuyển đổi toàn bộ mã lệnh GTA V sang C thuần và biên dịch bằng Apple Clang `-O2` trực tiếp ra file nhị phân **Mach-O ARM64 (`PlayGTA5Native`)**.
  - Không thông qua máy ảo JIT, không dùng Wasmtime, chạy ở tốc độ thực thi trực tiếp trên silicon của chip Apple Silicon.
  - Bộ dựng hình **Metal D3D11 Ring (`MRRenderer.mm`)** kết hợp shader nhị phân tiền biên dịch (`shaders-iphoneos.metallib`), loại bỏ hoàn toàn hiện tượng khựng khung hình do nạp shader.

- **Bộ nhớ Native Memory Guard (Chống văng OOM Jetsam):**
  - Giữ cố định vùng đệm an toàn **384 MiB** trước trần RAM của iOS (`os_proc_available_memory()`).
  - Tự động ra lệnh cho bộ streaming nội bộ của GTA V giải phóng (evict) texture và model ở xa khi RAM căng thẳng, chấm dứt triệt để tình trạng văng game do đầy bộ nhớ.

- **Cầu nối Mạng Đa người chơi Native (Online Bridge):**
  - Tích hợp module mạng tĩnh siêu nhẹ kết nối trực tiếp giao thức UDP máy chủ AWS Singapore (`18.143.103.253`).
  - Giao diện cài đặt Online chuẩn UIKit của Port, có thanh cuộn hỗ trợ các dòng máy màn hình nhỏ (iPhone SE).
  - Tự động đồng bộ luật PvP / Co-op và khóa mã cheat khi online để đảm bảo công bằng.

- **Hệ thống Điều khiển & Phím ảo GTA Port:**
  - Đầy đủ bộ icon phím bấm cảm ứng đặc trưng của GTA Port (`icon_aim`, `icon_fire`, `icon_gas`, `icon_brake`, `icon_weapons`,...).
  - Hỗ trợ tay cầm vật lý thực (`GCExtendedGamepad`): Tự động ẩn phím ảo trên màn hình khi kết nối và kích hoạt Apple Game Mode.

- **Khắc phục hoàn toàn lỗi Icon trên màn hình chính (Springboard):**
  - Đóng gói Asset Catalog chuẩn `Assets.car` với biểu tượng chữ "V" Los Santos hoàng hôn Del Perro Pier 1024×1024.
  - Bổ sung sẵn các file icon PNG `AppIcon60x60@2x.png` và `AppIcon76x76@2x~ipad.png` trong gói bundle.

---

### 📦 Các bản cài đặt IPA đính kèm:
* **`Mugoat.ipa`** (85.7 MB): Bản cài đặt tiêu chuẩn hợp nhất, tương thích mọi công cụ sideload.
  - SHA-256: `617e1f35afdebd7bda657a11045e3e822c7de1b354e8920b9c64d1e3262dfc25`
* **`Mugoat-Cert-Paid.ipa`** (85.7 MB): Bản tối ưu mở rộng bộ nhớ (Extended Memory Limit & Extended Virtual Addressing) dành cho TrollStore, chứng chỉ doanh nghiệp và chứng chỉ cá nhân trả phí (ESign, Scarlet, GBox,...).
  - SHA-256: `617e1f35afdebd7bda657a11045e3e822c7de1b354e8920b9c64d1e3262dfc25`
* **`Mugoat-AppleID-Free.ipa`** (85.7 MB): Bản tương thích chứng chỉ Apple ID miễn phí (AltStore, SideStore, Sideloadly 7 ngày).
  - SHA-256: `8c3f4016f5cf84777fd790cb7cece218bb9d62f92402aa1034abc0328295e4c2`
