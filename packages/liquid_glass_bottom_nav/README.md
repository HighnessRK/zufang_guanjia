# liquid_glass_bottom_nav

A floating frosted-glass pill bottom navigation bar for Flutter. Features a physics-based sliding bubble indicator, drag-to-switch gestures, and a squash-and-stretch tilt animation. Built on top of [`liquid_glass_renderer`](https://pub.dev/packages/liquid_glass_renderer) — embedded directly, so no extra dependency is needed.

Automatically falls back to a standard Material bottom nav on devices that don't support Impeller (Skia, web, Windows, Linux).

![LiquidGlassNavBar demo](https://raw.githubusercontent.com/akbardzulfikar/liquid_glass_bottom_nav/main/assets/demo.png)

---

## Installation

```yaml
dependencies:
  liquid_glass_bottom_nav: ^0.0.11
```

---

## Try the example app

`example/` is a full interactive playground — tab count, active color, icon size, capsule radius, badge count, legacy-fallback toggle, drag rainbow border, and liquid active bubble are all live-tunable from its Settings tab. Ships with `ios/` and `android/` platform folders.

```bash
cd example
flutter run                  # auto-picks a device if only one is connected
flutter run -d <device-id>   # or pick one from `flutter devices`
```

No simulator/emulator booted yet? See [example/README.md](example/README.md) for exact boot commands.

---

## Quick start

Wrap your `Scaffold` body in a `Stack` and place `LiquidGlassNavBar` as a `Positioned` overlay at the bottom. Add `LiquidGlassNavBar.contentBottomInset` as bottom padding on any scrollable content so it clears the nav bar.

```dart
import 'package:liquid_glass_bottom_nav/liquid_glass_bottom_nav.dart';

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int _selectedIndex = 0;

  final _items = const [
    LiquidGlassNavItem(id: 'home',    icon: Icons.home_rounded,   label: 'Home'),
    LiquidGlassNavItem(id: 'search',  icon: Icons.search_rounded,  label: 'Search'),
    LiquidGlassNavItem(id: 'profile', icon: Icons.person_rounded,  label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Your page content — add bottom padding so it clears the nav bar
          Positioned.fill(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(
                bottom: LiquidGlassNavBar.contentBottomInset,
              ),
              child: /* your content */,
            ),
          ),

          // The nav bar
          LiquidGlassNavBar(
            items: _items,
            selectedIndex: _selectedIndex,
            onTap: (index) => setState(() => _selectedIndex = index),
          ),
        ],
      ),
    );
  }
}
```

---

## Customization

### Colors

```dart
LiquidGlassNavBar(
  items: _items,
  selectedIndex: _selectedIndex,
  onTap: (i) => setState(() => _selectedIndex = i),
  activeColor: const Color(0xFF4CAF50),   // active icon + label
  inactiveColor: Colors.white60,          // inactive icon + label
),
```

### Icon size and label style

```dart
LiquidGlassNavBar(
  items: _items,
  selectedIndex: _selectedIndex,
  onTap: (i) => setState(() => _selectedIndex = i),
  iconSize: 24,
  labelStyle: const TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.3,
  ),
),
```

### Custom icon widget

Use `iconWidget` when you need an SVG, asset image, or any custom painter instead of a `IconData`. The widget is wrapped in `IconTheme` so any widget that respects it (including `SvgPicture.asset` with `colorFilter: ColorFilter.mode(iconTheme.color!, BlendMode.srcIn)`) will automatically receive the active/inactive color.

```dart
LiquidGlassNavItem(
  id: 'mosque',
  label: 'Prayer',
  iconWidget: SvgPicture.asset(
    'assets/icons/mosque.svg',
    colorFilter: ColorFilter.mode(
      IconTheme.of(context).color ?? Colors.white,
      BlendMode.srcIn,
    ),
  ),
),
```

### Insets

```dart
LiquidGlassNavBar(
  items: _items,
  selectedIndex: _selectedIndex,
  onTap: (i) => setState(() => _selectedIndex = i),
  insets: 12.0,   // horizontal margin from screen edge + bottom margin above safe area
),
```

### Capsule radius

`borderRadius` controls the corner radius of the floating capsule. It defaults to `34.0`, which — at the bar's fixed 68px height — renders as a full stadium/pill. Lower it for a squarer capsule; the active tab bubble automatically follows the same radius so its shape always matches the capsule around it.

```dart
LiquidGlassNavBar(
  items: _items,
  selectedIndex: _selectedIndex,
  onTap: (i) => setState(() => _selectedIndex = i),
  borderRadius: 16.0,
),
```

Only affects the Impeller-rendered capsule — the legacy fallback bar (used when `impellerSupported` is `false`) is a full-width bar with no capsule shape, so `borderRadius` has no effect there.

### Bubble-sheen border while dragging

While actively dragging, the held capsule (already larger than the resting pill — see the drag mechanics above) loses its flat `activeColor` tint and its border becomes a soft iridescent "soap bubble" sheen instead — a blurred pastel gradient rim with a glossy highlight. The icon and label themselves are never scaled; only the capsule's own hold-state growth and this border change.

```dart
LiquidGlassNavBar(
  items: _items,
  selectedIndex: _selectedIndex,
  onTap: (i) => setState(() => _selectedIndex = i),
  dragRainbowBorder: false,   // opt out, back to a flat activeColor stroke
),
```

A plain-widget effect (a static `CustomPainter`) — no `BackdropFilter` or shader involved, so it adds no per-frame rendering cost during drag.

### Real glass on the held bubble (`liquidActiveBubble`)

By default the bubble is always a plain tinted `BoxDecoration` — cheap, and consistent with the "keep glass shapes static" guidance below. Setting `liquidActiveBubble: true` swaps it for a real [`LiquidGlass`](https://pub.dev/packages/liquid_glass_renderer) shape instead, but **only while actively held/dragging** — the resting (selected-but-not-dragging) bubble always stays the plain tinted container regardless of this flag.

```dart
LiquidGlassNavBar(
  items: _items,
  selectedIndex: _selectedIndex,
  onTap: (i) => setState(() => _selectedIndex = i),
  liquidActiveBubble: true,
),
```

**This is off by default for a reason.** While held, this bubble's position and size animate every drag frame. With `liquidActiveBubble: true`, the glass shader recomputes (`toImageSync()`) on every one of those frames — the exact per-frame shader cost this package otherwise avoids everywhere else by keeping all glass shapes static. Test on real mid/low-end Android hardware before shipping with this enabled; it has not been profiled for frame-time impact.

### Badge count

Set `badgeCount` on a `LiquidGlassNavItem` to show a small badge on that tab's icon — e.g. for unread notifications. `badgeColor`, `badgeTextColor`, and `badgeBorderRadius` are per-item, so different tabs can have different badge styling. Works in both Impeller and legacy fallback modes.

```dart
LiquidGlassNavItem(
  id: 'alerts',
  icon: Icons.notifications_rounded,
  label: 'Alerts',
  badgeCount: unreadCount,             // null or <= 0 hides the badge; caps display at "99+"
  badgeColor: Colors.red,              // defaults to colorScheme.error
  badgeTextColor: Colors.white,        // defaults to colorScheme.onError
  badgeBorderRadius: 999,              // defaults to 999 (fully rounded); lower for a squarer badge
),
```

The badge is a pure reflection of `badgeCount` — the package has no built-in "dismiss on tap" behavior. To clear it, update your own state (e.g. when the user reads their notifications) and pass `badgeCount: null` or `0` back into the item:

```dart
LiquidGlassNavItem(
  id: 'alerts',
  icon: Icons.notifications_rounded,
  label: 'Alerts',
  badgeCount: _unreadCount == 0 ? null : _unreadCount,
),

// elsewhere, e.g. when the Alerts tab is opened:
onTap: (index) {
  setState(() {
    _selectedIndex = index;
    if (index == alertsIndex) _unreadCount = 0;
  });
},
```

---

## API reference

### `LiquidGlassNavBar`

| Parameter | Type | Default | Description |
|---|---|---|---|
| `items` | `List<LiquidGlassNavItem>` | required | Navigation items |
| `selectedIndex` | `int` | required | Index of the active tab |
| `onTap` | `ValueChanged<int>` | required | Called when a tab is tapped or dragged to |
| `activeColor` | `Color?` | `colorScheme.primary` | Icon and label color for the active tab |
| `inactiveColor` | `Color?` | `colorScheme.onSurface` | Icon and label color for inactive tabs |
| `iconSize` | `double` | `22` | Size of the icon in each tab |
| `labelStyle` | `TextStyle?` | `bodySmall + w500` | Merged over the default label style. Color is always driven by active/inactive color. |
| `insets` | `double` | `16` | Horizontal margin from screen edge and bottom margin above the system safe area |
| `borderRadius` | `double` | `34` | Corner radius of the floating capsule. The active tab bubble follows the same radius. No effect on the legacy fallback bar. |
| `dragRainbowBorder` | `bool` | `true` | When true, the held bubble's border is a pastel gradient sheen instead of a tinted `activeColor` stroke. |
| `liquidActiveBubble` | `bool` | `false` | When true, the bubble is a real `LiquidGlass` shape while held/dragging (resting state is unaffected). Animates every drag frame — not profiled for frame-time impact, off by default. |
| `impellerSupported` | `bool` | `true` | Pass `false` to force the legacy Material fallback (useful when Impeller is unavailable) |

### `LiquidGlassNavItem`

| Parameter | Type | Required | Description |
|---|---|---|---|
| `id` | `String` | yes | Unique identifier for this item |
| `label` | `String` | yes | Tab label text |
| `icon` | `IconData?` | one of `icon`/`iconWidget` | Material or Cupertino icon |
| `iconWidget` | `Widget?` | one of `icon`/`iconWidget` | Custom icon widget — takes priority over `icon`. Wrapped in `IconTheme`. |
| `badgeCount` | `int?` | no | Notification count shown as a badge on the icon. `null` or `<= 0` hides it; values above 99 display as `"99+"`. |
| `badgeColor` | `Color?` | no | Badge background color. Defaults to `colorScheme.error`. |
| `badgeTextColor` | `Color?` | no | Badge text color. Defaults to `colorScheme.onError`. |
| `badgeBorderRadius` | `double` | no (default `999`) | Corner radius of the badge shape. `999` is fully rounded; lower for a squarer badge. |

### Static constants

| Constant | Value | Description |
|---|---|---|
| `LiquidGlassNavBar.contentBottomInset` | `96.0` | Bottom padding to add to scrollable content so it clears the floating nav bar |

---

## LiquidGlassBackButton

A floating glass back button that matches the nav bar's visual language. Place it as a top-left overlay inside a `Stack`.

```dart
Stack(
  children: [
    YourPageContent(),
    Positioned(
      top: MediaQuery.of(context).padding.top + 12,
      left: 16,
      child: LiquidGlassBackButton(
        onTap: () => Navigator.of(context).pop(),
      ),
    ),
  ],
)
```

### `LiquidGlassBackButton`

| Parameter | Type | Default | Description |
|---|---|---|---|
| `onTap` | `VoidCallback?` | `Navigator.maybePop` | Tap handler. Defaults to popping the current route. |
| `color` | `Color?` | `colorScheme.onSurface` | Chevron icon color |
| `size` | `double` | `44` | Width and height of the glass pill |
| `borderRadius` | `double` | `14` | Corner radius of the glass shape |
| `impellerSupported` | `bool` | `true` | Pass `false` to fall back to a plain `IconButton` |

---

## Impeller note

The glass effect requires Flutter's **Impeller** renderer.

- **iOS** — Impeller is on by default. No action needed.
- **Android** — Impeller must be enabled in `AndroidManifest.xml`:

```xml
<meta-data
  android:name="io.flutter.embedding.android.EnableImpeller"
  android:value="true" />
```

When Impeller is unavailable (older Android, web, desktop), the widget automatically renders a standard Material bottom navigation bar. You can also force the fallback by passing `impellerSupported: false`.

---

## License

MIT
