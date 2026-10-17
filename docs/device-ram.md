# Native device RAM detection

Mugoat 1.1.6 removes the host's streaming RAM clamp and its 384 MiB reserve.
It also stops forcing `lowMemory`, removes the streaming percentage override,
and sizes the native virtual heap from `hw.memsize` instead of 4095 MiB.
The initial logical heap stays small and pages are committed on demand.

The pinned engine imports shared memory64 with 49152..262144 pages of 64 KiB:
3..16 GiB. `NativeEngineMemory.h` respects these engine ABI bounds while allowing
the full 4/6/8/12/16 GiB device capacity. Devices above 16 GiB require a different
engine to address more than its declared maximum. The app adds no smaller cap.

The interface reports physical RAM, including its fractional GiB value rather
than truncating it to a whole number. Preset recommendations use physical RAM.
Process allowance and current iOS headroom are diagnostics, never heap limits.
The increased-memory-limit and extended-virtual-addressing entitlements remain
requested by both package variants; the OS and provisioning profile determine
the actual process allowance.

`restore_engine_memory.py` removes both old budget hooks from regenerated or
cached C shards before every native build. `Tests/memory_configuration.py`
checks this migration and compares the policy to the actual pinned engine.
The C test covers 3/4/6/8/12/16 GiB devices and engine/page-size boundaries.

CI uses released Node 24 actions: checkout 7.0.1, upload-artifact 7.0.2 and
cache 6.1.0. A macOS ARM runner capacity notice is emitted by GitHub's scheduler
and does not indicate an app or Node error.
