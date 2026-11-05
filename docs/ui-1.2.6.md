# V1.2.6 UI and sync review

Reviewed UI sources across the home, room, meter, collection, report, receipt,
notification and settings flows, their shared fields/buttons, dialogs and navigation.
Changes concentrate on shared presentation so pages retain consistent spacing,
semantics and accessibility rather than each acquiring a separate visual system.

- App-wide toast is now a single overlay above routes, with a glass capsule,
  explicit readable text style, navigation/keyboard clearance and working actions.
- MCP copy actions use the same GlassCard radius and typography as settings;
  capabilities use the shared dialog instead of a Material AlertDialog.
- Material fallback dialogs/buttons inherit 26/14 radius and theme colors.
- Navigation keeps static optical geometry, stronger blur, reduced saturation and
  rim refraction. Animated drag feedback remains plain widgets to avoid expensive
  per-frame background capture. Android still uses the native shader renderer.
- Brand is vector-native with adaptive Android foreground/background layers and
  density-specific legacy icons. About uses the same geometry and aurora palette.
- Feishu exposes bidirectional sync and a separate incremental cloud pull. Pull
  plans issue no remote writes and retain the remote baseline, so unuploaded local
  edits remain eligible for a future sync. Conflicts stop both paths.
- Chip names use known SoC IDs; unknown boards are not shown as hardware names.
  Installed AAR has libggml-cpu, not Hexagon. UI distinguishes hardware NPU support
  from the CPU execution backend; this release does not enable NPU inference.

Validation: automated suite covers settings at three font scales, major data
pages, toast layout/actions, pull plans and conflicts, chip names, OCR and billing.
125 tests pass and analysis is clean. Device review checked MCP cards, corrected
toast typography, Feishu cloud-update entry and the new About icon, plus an
in-place release install. No cloud ledger rows were edited for a visual test.
