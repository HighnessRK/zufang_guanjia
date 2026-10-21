## 0.0.14

* Change: `LiquidGlassNavBar`'s held-tab feedback replaced. The old drag tilt (`rotateZ` + direction-dependent squash/stretch driven by horizontal drag delta) is gone. In its place: a direction-independent vertical spring squash that responds continuously to drag movement and settles back to neutral with a subtle overshoot (`Curves.easeOutBack`) once the finger pauses.
* Change: `dragRainbowBorder` now defaults to `false`. The held bubble's default accent is a light gray stroke instead of the iridescent sheen; the rainbow ring is still available by setting `dragRainbowBorder: true`. The stroke now renders consistently whether `liquidActiveBubble` is on or off.
* Change: `liquidActiveBubble` now defaults to `true` — the held bubble renders as a real `LiquidGlass` shape by default. See the updated doc comment for the per-frame shader-recompute tradeoff on low-end Android hardware; set to `false` to opt back into the plain tinted container.

## 0.0.13

* Fix: `equatable` constraint lower bound (`^2.0.7`) allowed resolving to a version where `Equatable` isn't a `mixin class`, which broke `with Equatable` in `LiquidGlassSettings`/`LiquidShape` and failed pub.dev's dependency-lower-bound (downgrade) check. Bumped to `^2.1.0`, the version that introduced `mixin class Equatable`.
* Fix: three shaders (`liquid_glass_geometry_blended.frag`, `liquid_glass_filter.frag`, `liquid_glass_arbitrary.frag`) failed to compile on the Skia/non-Impeller fallback backend (used on some older/unsupported Android devices), crashing app startup with `impellerc failure: Compilation failed for target: SkSL`. Root causes: (1) the shape-data array was passed by value into a nested helper function, which spirv-cross cross-compiles to an SkSL array copy-with-initializer that SkSL rejects; inlined the helper so the array is only ever a single-level parameter. (2) a blur-radius loop used a non-`const` local as its bound, which SkSL requires to be a literal constant; hardcoded the loop bounds. No visual or API changes.

## 0.0.12

* Docs: replace the top-of-README demo placeholder with a real screenshot of the example app (`assets/demo.png`).

## 0.0.11

* Add `dragRainbowBorder` to `LiquidGlassNavBar` (default `true`) — while a tab is held/dragging, its border becomes a soft iridescent "soap bubble" sheen (blurred pastel gradient rim + glossy highlight) instead of a flat `activeColor` stroke. Plain `CustomPainter` effect, no extra per-frame cost. Set to `false` to keep the old flat border.
* Add `liquidActiveBubble` to `LiquidGlassNavBar` (default `false`, opt-in) — renders the held drag bubble as a real `LiquidGlass` shape instead of a plain tinted container. Only applies while actively dragging; the resting selected bubble is unaffected. Off by default: this animates the glass shape's position/size every drag frame, forcing a per-frame shader recompute — test on real mid/low-end Android hardware before enabling in production.
* Fix: migrate `LiquidGlassSettings` and `LiquidShape` off the deprecated `EquatableMixin` to `Equatable` (usable as a mixin since `equatable` 2.1.0), resolving a pub.dev static analysis warning.

## 0.0.10

* Add `badgeCount`, `badgeColor`, `badgeTextColor`, `badgeBorderRadius` to `LiquidGlassNavItem` — shows a small notification badge on a tab's icon, styled per-item. `badgeCount` null or `<= 0` hides the badge; values above 99 display as "99+". Works in both Impeller and legacy fallback modes.
* Add `borderRadius` param to `LiquidGlassNavBar` (default `34.0`) — customizes the corner radius of the floating capsule. The active tab bubble indicator now follows the same radius instead of always rendering as a full pill.

## 0.0.9

* Add `fake` param to `LiquidGlassContainer` — when `true`, renders the cheap `FakeGlass` approximation instead of the real refraction shader. No geometry shader, no per-frame transform tracking, so it stays smooth inside scrolling/paging content. Best for glass placed over a flat/solid background, where real refraction has nothing meaningful to refract.
* Add `fake` and `ownLayer` params to `LiquidGlassBackButton`, matching the options already on `LiquidGlassContainer`. `fake: true` avoids Android overscroll distortion artifacts when the button sits inside scrolling/paging content.

## 0.0.8

* Add `ownLayer` param to `LiquidGlassContainer` — when `false`, the container joins a parent `LiquidGlassLayer` instead of creating its own layer, reducing N shader passes to 1 for grouped cards.
* Add `backgroundColor` param to `LiquidGlassContainer` — true opaque solid fill inside the glass shape, independent of the `glassColor` shader tint. Enables iOS-native-style solid-color glass containers.
* Add `saturation` and `thickness` params to `LiquidGlassContainer` — previously hardcoded, now fully customizable for vibrancy and refraction tuning.
* Export `LiquidGlassLayer` and `LiquidGlassSettings` from the main library entry point.
* Add `LiquidGlassRenderScope.maybeOf(BuildContext)` for safe scope detection.
* Nav bar light mode: active bubble indicator now uses `activeColor` tint instead of white, making it visible against the white capsule background.
* Nav bar light mode: capsule `glassColor` alpha increased to 0.76 and `blur` settled at 1 for clean vibrant white appearance without fogging.

## 0.0.7

* Add `LiquidGlassBackButton` — floating frosted-glass back button with chevron icon, touch glow via `GlassGlow`, and press scale feedback. Falls back to plain `IconButton` on non-Impeller targets.
* Tune glass settings for stronger liquid glass refraction: higher `thickness` (32), lower `blur` (1), reduced `glassColor` opacity — applies to both nav bar and back button.

## 0.0.6

* Add demo GIF placeholder to README — drop `assets/demo.gif` to activate.
* Wire `assets/` directory for hosting demo media.

## 0.0.5

* Add `example/` app with interactive demos: dark/light mode toggle, 3/4/5 tab selector, active color picker, icon size slider, and legacy fallback toggle.
* Add `CLAUDE.md` and `AGENTS.md` with commit convention, renderer performance rules, and workflow guidelines.

## 0.0.4

* Add `iconSize` param to control icon size across all tabs (default: 22).
* Add `labelStyle` param for custom label typography, merged over `bodySmall`. Color always follows active/inactive color.
* Add `iconWidget` to `LiquidGlassNavItem` for custom icon widgets (SVG, asset, painter). Takes priority over `icon`; wrapped in `IconTheme` for automatic color inheritance.
* Make `icon` optional in `LiquidGlassNavItem` — required only when `iconWidget` is not provided.
* Fix held bubble capsule clipping outside leftmost/rightmost tab boundaries during drag.
* Rewrite README with full API reference, usage examples, and Impeller setup instructions.

## 0.0.3

* Embed `liquid_glass_renderer` internally for zero-dependency usage.
* Add physics-based squish and stretch animations that react smoothly to drag velocity.

## 0.0.2

* Update metadata and prepare for initial release.

## 0.0.1

* Initial release of liquid_glass_bottom_nav.
