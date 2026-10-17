# Water rendering investigation — 1.1.6

The player reports black, flickering water. No matching on-device capture or log has been supplied, so
the reported visual fault is **not confirmed fixed**.

The SHA-256-pinned shader index for engine `8b0b5899ed` contains 100 supported
vertex/fragment water programs, including ocean height/depth, near/far ocean,
river, pool, foam, refraction and underwater fog. None is missing from the source
index. The normal graphics baseline already uses WaterQuality 0 and disables
unsupported tessellation/MSAA; raising those settings without a reproduction
would not establish a fix.

The shader build now checks exact translated hash/stage coverage and fails if any
Metal compile batch fails. Previously it continued to link, potentially using
older AIR files from cache after a failed recompile. The IPA validator checks all
100 water reflection entries and core surface/underwater programs before release.
These checks establish packaged shader coverage, not correct pixels on a phone.

A renderer fault was also found: fallback textures for unbound resources were
allocated in private Metal memory without initialization. They now explicitly
contain zero, matching D3D11's unbound-resource behavior. Color/array/cube/volume
fallbacks use tiny initialized shared textures; depth and multisample fallbacks
are cleared in a separate command buffer on the same queue before sampling.
The active render pass and its binding cache are preserved. A Metal regression
test first poisons textures with nonzero data and checks zero after initialization,
including GPU reads of private depth and multisample textures. A CI runner with
no GPU reports a skip explicitly. Device confirmation of the player's water
symptom remains necessary.

Local game logs now include:

- `[water] library`: program count and missing Metal entry points on startup.
- `[water] ... tN unavailable`: shader/material, texture slot, resource IDs and
  DXGI format when the renderer must bind a fallback texture. Some unused slots
  can legitimately be absent; this is diagnostic evidence, not a user error.
- `[water] draw skipped`: material and reason for a skipped draw other than
  temporary asynchronous pipeline compilation.
- `[water] interval`: submitted/skipped/waiting water draws and fallback texture
  bindings in each normal 10-second renderer log interval. A submitted draw alone
  does not establish correct rendering.

There is no new network upload or screenshot capture. These lines enter the same
local game log as other renderer diagnostics.

To reproduce on a real device: record the app version, iPhone model, iOS version,
graphics preset and location; test coastline close/far views, shallow river/pool,
swimming below the surface, and camera rotation at the waterline. Compare offline
and online at the same location. Include the nearby `[water]`, pipeline failure
and GPU command-buffer error lines with the player's screenshot/video.
