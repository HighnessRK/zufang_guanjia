# liquid_glass_bottom_nav — example

Interactive playground for the `liquid_glass_bottom_nav` package. The Settings tab lets you live-tune tab count (3–5), active color, icon size, capsule radius, badge count, the legacy-fallback toggle, drag rainbow border, and the liquid active bubble — everything documented in the [root README](../README.md).

## Running it

From this `example/` directory:

```bash
flutter pub get
flutter devices     # see what's currently available
flutter run          # auto-picks a device if only one is connected
```

If more than one device is attached, pick one by id:

```bash
flutter run -d <device-id>
```

### iOS Simulator

```bash
open -a Simulator                # boots the last-used simulator
flutter run -d "iPhone 17 Pro"   # or whichever simulator you booted
```

### Android emulator

```bash
flutter emulators                     # list configured AVDs
flutter emulators --launch Pixel_6a   # boot one (swap in your AVD's id)
flutter run                            # waits for the emulator, then runs
```

No AVD yet? Create one from Android Studio's Device Manager (or `avdmanager`), then `flutter emulators --launch <id>`.

### Physical device

Plug in and unlock an iOS or Android device, trust the computer if prompted, then `flutter run -d <device-id>`.

## Platform support

Only `ios/` and `android/` are checked in — `macos/`, `web/`, `linux/`, and `windows/` aren't set up. Add any of them with `flutter create --platforms=<platform> .` from this directory if you need to try the demo there; the package itself doesn't restrict which platforms it runs on.
