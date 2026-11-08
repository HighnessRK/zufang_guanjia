# V1.2.9 validation — 2026-11-08

## UI changes

- Replaced whole-pane outward displacement with inward Snell-law refraction at a static slab bevel; the flat interior uses its original screen position.
- Added an independent analytic convex selection lens. Drag updates scalar/rectangle uniforms rather than animated LiquidGlass geometry or texture readback. Navigation controls remain outside both optical filters.
- Incorporated device feedback: continuous background softening and tonal contrast protect labels; a theme-tinted selection has stronger type and natural surface highlights with no separately drawn colored border. Inactive items have no individual disk fills. Shader-unavailable renderers keep a continuous softened pane.
- Shared ambient/action palettes cover five effects, primary actions, progress, selection, home/receipt decoration and recognition entry points. Semantic arrears/paid/water/electricity colors retain their meaning. Removed redundant CTA backdrop blurs.
- Secondary choice/confirmation panels now reuse GlassCard material: blurred backdrop, translucent sheen, rounded silhouette and readable foregrounds instead of a solid surface.
- Restored the data/Feishu settings divider. Fixed invisible dark-mode dialog headings and the root content-color scope used by popups.

## Automated checks

- Final full suite: 137 tests passed, including the final modal glass material. Static analysis: no issues.
- Matrix expanded to nineteen pages × two themes × five effects at 125% text scaling (190 compositions); existing complete settings and nonempty collection/report/receipt checks also cover 100%, 110% and 125% scaling.
- Added checks for mounted-button live palette changes, white CTA text contrast >= 4.5:1, title contrast in both themes, settings dividers, navigation release/cancel and held-lens enlargement. Corner pixels and inactive-pane continuity remain covered.

## Device checks

- Connected Xiaomi Snapdragon 8 Gen 3 / Android 16, Impeller; synthetic data isolated in com.zufang.guanjia.ocrprobe. No production ledger/configuration was edited by probe QA.
- Inspected all five tabs in light/dark across all five effects. Selected semantics follow each tab. Checked busy content under the pane, held-lens overflow and the settings divider.
- Changed effect through the actual preference picker, then toggled Android night mode without restarting: PID 23830 was retained. System night mode restored to its original auto setting.
- Recognition and acceleration choice panels exercised. Found and corrected their dark title issue; final jade/light and jade/dark captures confirm the glass panel, visible heading and clear choice labels.
- Production APK signature verified against the existing certificate; package com.zufang.guanjia, versionName 1.2.9, versionCode 24. Covered installation and cold launch succeeded; the home room count remained 14 before/after. Original first-install timestamp was preserved.

## Limits

Visual/device acceptance covers the connected Snapdragon 8 Gen 3 handset; other GPU/SoC combinations are covered by fallback behavior and widget/layout checks, not physical-device measurements. NPU inference behavior is unchanged in this UI release.

## Artifact

APK: 19,286,994 bytes (18.4 MiB). SHA256: `6476a986ddce3af9c614ac8b6fe5a201549fba622c3a922445c9b58e2775f8dd`.
Signing certificate SHA256: `0c8771013148bb51f04d0c0aa5232a5bca97ce04cca9a546f34fafb88e633397`.
