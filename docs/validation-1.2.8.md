# V1.2.8 validation — 2026-11-06

- Static analysis: no issues. Full suite: 132 tests passed.
- New regression tests sample all four navigation corners and the empty area
  of inactive items in light/dark mode. They reject colored remnants and
  per-option radial fills. Selection remains one flat highlight.
- A mounted const AuroraBackground updates through saved ocean/sunset/jade/
  aurora/none preferences without replacing its element; system brightness
  changes also update the existing component.
- Connected Snapdragon 8 Gen 3 / Android 16: switched background effects via
  the actual picker, then changed Android system night mode, with the app PID
  unchanged. Verified palette changes and foreground/material updates.
- Added synthetic fourth-floor rooms to the isolated UI probe. Scrolled the
  meter screen until its gradient save button passed directly beneath the
  navigation. Inspected both system light and system dark captures: clipped
  continuous rim, no corner rectangle or individual option halos, and readable
  flat selection. Top-bar titles remain protected as meter fields scroll under
  the fade. No production ledger is used for this scene.
- Cold inference probe skipped all main-isolate library preloading. First
  backend discovery selected HTP0; synthetic digits matched using Hexagon NPU
  + CPU. Backend/model preparation and inference after model verification took
  4.909 seconds on this device. This is a functional check, not a general speed
  benchmark. No inference code changed in this release.
- Signed release APK SHA256:
  `1fcf373040fe4c8fa87abb3fa901229de4bdc6b76524bb600ed76b3cda9f4f71`.
  Signing certificate matches previous releases:
  `0c8771013148bb51f04d0c0aa5232a5bca97ce04cca9a546f34fafb88e633397`.

The clear pane now clips both optics and foreground to the same outline,
has no outside shadow, and no longer magnifies text under control labels.
Only the continuous rim refracts strongly. A theme-bound reflected-light
uniform replaces black per-item masks. The top-bar fade retains strong blur
and surface protection through the title region, with a 28dp trailing fade.
The background listens directly to configuration changes so const reuse does
not leave stale colors. Production preferences/data are not edited by probe QA.
