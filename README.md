# Mugoat — iOSVN

Mugoat combines Port's native C/ARM64 and Metal engine with Port's contextual
buttons, Muguet-style relative drag aiming, and Muguet multiplayer. iOS 16.0+.
The app icon and home logo use the green metallic V on a black background.

- The game engine and renderer run natively. The static Rust library handles
  networking and replicas; it does not include Wasmtime or wgpu.
- Full physical device RAM is recognized without an app-imposed percentage or
  384 MiB streaming reserve. The engine ABI and iOS process allowance still apply.
  BC1–BC7 decoding, precompiled Metal shaders, native futexes and asset hints remain.
- Camera/Aim/Fire dragging uses independent fingers without a right floating
  joystick. Gamepad aim assistance, movement, vehicles and Port's menus remain.
- Actual renderer FPS, Vietnamese/English, save backup/import/export and
  one map (Los Santos) are available.
- Online settings accept the existing server, room, player name and PvP
  preference. Older Documents/config.json and Documents/saves are retained.

## Build

Use GitHub Actions **Build Mugoat Single IPA** (`build-game-ipa.yml`) or
**Build Mugoat Native IPA**. Both use the same native pipeline and create Free
and Paid signing variants of one executable. Historical Rust/wgpu workflows
are outside the active workflow directory to prevent accidental old builds.

Locally, on an Apple Silicon Mac with Xcode, xcodegen and Rust's
`aarch64-apple-ios` target:

```
cd native-port
./build_ipa.sh --mirror /path/to/your/game-files
```

See [release notes](RELEASE_NOTES.md), [native integration](native-port/HYBRID.md)
and the [upstream reference](docs/UPSTREAM-MUGUET.md). Required source and license
notices remain in the repository and are bundled in the app.

## Validation limits

Build-time checks cover FFI signatures, memory bounds, protocol relay, camera
input, memory budget arithmetic, FPS, save integrity, BC textures and futexes.
The packaged Mach-O and Info.plist are checked for ARM64 and minimum iOS 16.0.
Actual UIKit previews cover Vietnamese/English and small/large iPhone screens.

Real-device frame pacing, thermals, Jetsam recovery and end-to-end native
multiplayer gameplay require device testing. Precompiled shader functions do
not remove pipeline setup; asset hints follow engine requests rather than a
new velocity predictor. Memory protection reduces risk and cannot guarantee
zero crashes or stutter on every phone.
