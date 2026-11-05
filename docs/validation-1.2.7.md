# V1.2.7 validation

- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub --reporter expanded`: 130 tests passed.
- The theme matrix test renders 12 pages × 2 explicit Miuix themes × 5
  backgrounds at 125% text scale (120 combinations). Existing tests cover
  full-length settings, room, meter, receipt, billing and report layouts.
- On the connected Snapdragon 8 Gen 3 / Android 16 device, 50 screenshots
  cover home, rooms, meter, report and settings across all 10 appearance
  combinations. Synthetic ledger data lives in a separate probe package.
- Icon selection was checked through the native method and Android launcher
  resolution: selecting Amber resolves exactly its launcher alias and persists.
- Native logs confirm HTP0 layer assignment and compute buffers. A real
  five-meter fixture completes with all five integer readings matching the
  expected sample, including while the probe is backgrounded. No private sample
  image or raw readings are committed. The synthetic single-number fixture also
  passes on CPU compatibility mode.
- Initial NPU image processing left neutral JPEG fragments in a red decimal
  digit. The mask now removes a small halo and applies to the fallback crop;
  the five-meter fixture was rerun successfully after the correction.
- Profile-mode repeated tab switching initially measured combined build+raster
  p95 around 37–40 ms per 60-frame sample. Removing dual-page backdrop fades
  and disabling unnecessary top-bar blur yields warm sample p95 14.83–17.90 ms
  on this device. This metric sums two pipeline stages; it is not a guarantee
  for other devices or every interaction. Hidden tabs retain state and stop
  ticking; navigation feedback and secondary-page transitions remain animated.
- The signed ARM64 release APK verifies with the existing certificate SHA256
  `0c8771013148bb51f04d0c0aa5232a5bca97ce04cca9a546f34fafb88e633397`.
  The build is approximately 18.4 MB. Native runtime provenance and supported
  backend limitations are described in runtime-1.2.7.md.

Clear navigation uses one analytic lens pass with monotonic magnification and
bilinear sampling. It has no fog blur or surface tint. Soft contrast behind
foreground controls protects labels; the outside-only shadow avoids a gray
fill in light mode. Top-bar fade uniforms use each panel's physical bounds,
not the full backdrop texture height. Selection dialogs share AppModalPanel;
camera/gallery, inference mode, acceleration, themes and confirmations use it.
