# Mugoat 1.1.3 (13) — Camera/Aim và quản lý Mod

Sửa nút Vào game bị khóa, loại file hướng dẫn `.txt` khỏi danh sách mod và bỏ hướng dẫn Mercedes. Camera/aim dùng cùng chiều trục dọc, gửi chuyển động một lần, giữ chuyển động nhỏ hơn một pixel và bỏ chuyển động tồn đọng sau khung hình chậm.

Xem [ghi chú bản 1.1.3](RELEASE_NOTES_V1.1.3.md) để biết thay đổi, kiểm tra và giới hạn xác minh trên thiết bị.

# Mugoat 1.1.0 (11) — Native hybrid, iOS 16.0+

Mugoat uses Port's native CPU/Metal renderer, Port's contextual touch buttons,
and Muguet's relative drag camera and existing UDP multiplayer replica logic.

- The release workflow compiles the pinned game with wasm2c-native and Clang
  for ARM64. It does not replace the native executable with the Rust/wgpu app.
- Metal shader libraries are built for iOS 16.0. Software BC1–BC7 decoding
  handles devices without BC support; the Swift hardware probe is guarded for
  iOS 16.4 rather than raising the minimum OS.
- Native memory queries retain the signed 384 MiB streaming reserve. Background
  asset hints use Utility/Background QoS and defer when this reserve is low.
- Movement, vehicles, weapons and menu buttons remain Port's layouts. Camera
  and aim dragging do not show a floating right joystick. Motion from camera,
  Aim and Fire is queued until the game reads pad 0, keeping assisted aiming
  and independent movement/fire fingers. Motion after a >50 ms engine stall
  is discarded; gyro and physical-controller axes remain supported.
- Actual renderer presentation-rate FPS is shown during play.
- Multiplayer uses Muguet's existing packets, interpolation and entity sync,
  via typed native game-function calls on the game thread. No Wasmtime/wgpu
  dependency is linked into the networking library. Enter the same server,
  room and game mode as other players. The existing default server is
  18.143.103.253:47520; use Story mode / room story for existing Muguet clients.
  Restart the app to change servers after starting the engine. Cheats are
  disabled through the app's utilities while online.
- Existing Documents/saves and online config.json settings are reused when
  upgrading the older build. The app retains bundle ID vn.iosvn.mugoat.
- The green metallic V on black is used for the app icon and home logo.
  Vietnamese/English, save backup/import/export and Los Santos remain available.

The code reduces memory pressure and avoids the old VM/rendering stack; it
cannot guarantee zero crashes or stutter on every iPhone. Device measurements,
end-to-end native multiplayer play and upgrade behavior need real-device
validation. Precompiled shader functions still require Metal pipeline setup.
Asset hints follow the engine's read requests, not a new velocity predictor.
This release does not claim a functioning Lua/ASI loader or RPF asset patcher.

Free and Paid packages contain the same executable. Paid memory entitlements
only apply when the installation's provisioning profile grants them. The
unsigned/ad-hoc packages must be signed before installation.
