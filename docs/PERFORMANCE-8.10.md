# Muguet 8.10: FPS and performance comparison

This build retains the Muguet AOT engine and wgpu/Metal renderer. It does not replace them with the GTA V Port C engine or its Metal renderer. No physical-device benchmark has been performed on this build.

## Changes

- A HUD enabled by default shows FPS, P95 frame interval, render resolution, app memory footprint and serious/critical thermal state. Toggle it in Graphics settings.
- Measurements count successful renderer presentation submissions, not CADisplayLink callbacks or the configured frame limit. They are not a measurement of completed display scanout. The sample window is approximately one second; inactive/stalled rendering expires after 1.5 seconds.
- Refresh-rate requests respect the screen maximum, including 60 Hz devices. VSync state is synchronized between UI/render threads and updates when toggled without changing the FPS limit. A timed-out display-link wait falls back to the remaining frame-pacer delay.
- Graphics cache pruning avoids walking and sorting entries when caches are within budget. Existing eviction limits and GPU ownership rules remain in place.
- Optional lightweight presets: 30 FPS at 35% resolution or 60 FPS at 50%. They reduce effects and model variety; game graphics quality requires reopening the game to apply fully. Existing preferences remain selected until the player changes them.
- Preset labels describe requested limits; they no longer promise sustained 120 FPS or a fixed 800 MB memory footprint.

## Source audit of GTA V Port comparison

Checked against the locally available GTA V Port source on 2026-10-13.

| Claim | What the code actually supports |
| --- | --- |
| Wasmtime means the game is interpreted at runtime | Muguet precompiles with `Engine::precompile_module` and embeds executable ARM64 code in `__GAME`. The iOS runtime loads it with `Module::deserialize_raw`, with the compiler feature disabled. Runtime host calls and bounds checks still exist; their cost requires measurement. |
| GTA V Port has a dedicated Metal renderer | Correct. It uses its own resource, shader and draw-command handling instead of wgpu. Source alone cannot establish a speedup on every phone. |
| Muguet cannot decode BC textures on older GPUs | Incorrect. It probes `TEXTURE_COMPRESSION_BC`, enables `BC_SOFT`, and uses `bcdec_rs` to decode BC textures before upload. GTA V Port also includes a BC decoder; the inspected decoder loops are synchronous, not a proof of multithreaded decoding. |
| DeviceTier forces low presets on all old phones | GTA V Port recommends presets using measured process memory headroom. Users can choose higher presets, with warnings. A 3.4 GB threshold refers to the estimated app memory limit, not simply installed physical RAM. |
| Quality 0 removes every reflection, grass and particle | These options request lower engine quality. Their literal names do not prove every effect is disabled. The low preset explicitly requests `shadowQuality=-1`; there is no benchmark here supporting a 40–50% draw reduction. |
| The 384 MB reserve guarantees no Jetsam | GTA V Port adjusts signed engine streaming budgets with 384 MB headroom; a negative budget requests eviction. This is not a preallocated 384 MB buffer or a guarantee against termination. Muguet already bounds heap growth and handles memory pressure, but those are not the same as these engine streaming hooks. |
| A metallib removes all compilation stutter | GTA V Port builds shader libraries ahead of time, but render pipeline states are still created asynchronously at runtime. This reduces shader-source translation work; it does not eliminate all pipeline creation or streaming stalls. Muguet currently loads WGSL at runtime. |

## Comparing on a phone

Use the same game data, save/location, camera, resolution in pixels and graphics quality on both apps. Use the same frame cap, signing memory entitlement, Low Power Mode and thermal conditions. Allow loading/pipeline creation to settle and then record at least one minute of gameplay. Compare FPS, P95, memory and visible stutter; a newer iOS version alone does not identify the bottleneck.

Physical-device checks still required: first launch, HUD toggle, menu/touch/gamepad visibility, 30/60/120 limits on both 60 and 120 Hz screens, VSync toggle at the same limit, background/resume, stalls, low-memory warnings and in-game graphics changes after relaunch.
