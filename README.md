# SwiftDrive

A car launcher for Android head units and tablets, built with Flutter and Kotlin (`com.swiftdrive.launcher`). Its
dashboard is designed for driving: map, now-playing media, clock and weather, GPS speed and a dock. It uses only
public Android APIs and works without root or Google Play Services. It never touches factory apps, the reverse
camera or the CAN bus.

> **Hardware status:** tested on an Android 9 head-unit emulator (1280×800, no Play Services). It has **not** been
> tested on a real head unit or on the 2026 Suzuki Swift. Radio, Bluetooth calling and steering-wheel support are
> **not** claimed. See [docs/COMPATIBILITY.md](docs/COMPATIBILITY.md) and
> [docs/HARDWARE_TESTING.md](docs/HARDWARE_TESTING.md).

## Features

- Dashboard with four layout presets that adapt from 1024×600 to 1920×720.
- Vector map (MapLibre + OpenFreeMap) with follow mode, for orientation; the Maps button opens your navigation app
  and voice prompts. Falls back to external navigation.
- Media controls for any app that publishes a media session (requires notification access).
- GPS speed (informational), Open-Meteo weather, notifications list.
- App drawer with search, favourites, hidden apps and pinning. Factory shortcuts for radio, phone, music,
  navigation and vehicle settings.
- Default-launcher setup and one-tap return to the factory launcher.
- Dark, light and sunrise/sunset themes; performance mode; diagnostics with JSON export.

The full matrix is in [docs/FEATURES.md](docs/FEATURES.md).

## Install

1. Download `app-release.apk` (or the ABI split for your unit, usually `arm64-v8a` or `armeabi-v7a`) and sideload
   it with `adb install` or a file manager.
2. Open SwiftDrive from the app list and follow onboarding.
3. Optional: Settings → Launcher → *Set as default launcher*. The same screen always offers a way back to the
   factory launcher.

## Build

Requirements: Flutter 3.47.5, Android SDK 37, and JDK 17 or newer (Android Studio's bundled JBR works).

```bash
flutter pub get
```

```bash
flutter build apk --release
```

```bash
flutter build apk --release --split-per-abi
```

Release signing reads `android/key.properties`; without it the APK is debug-signed (see
[docs/SECURITY.md](docs/SECURITY.md)).

## Test

```bash
flutter analyze
```

```bash
flutter test
```

```bash
flutter test integration_test -d <device-id>
```

Native tests: run `./gradlew :app:testDebugUnitTest` from `android/`. Details are in
[docs/TESTING.md](docs/TESTING.md).

## Services and licences

The default endpoints are free, keyless services intended for personal, non-commercial use:
- OpenFreeMap (map data © OpenStreetMap contributors)
- Open-Meteo
- FOSSGIS OSRM
- Nominatim

All of them can be changed in Settings. Open-source licences are listed under Settings → About.

## Documentation

| | |
|---|---|
| [ARCHITECTURE](docs/ARCHITECTURE.md) | layers, channels, lifecycle |
| [FEATURES](docs/FEATURES.md) | status matrix |
| [COMPATIBILITY](docs/COMPATIBILITY.md) | devices and capability dependencies |
| [TESTING](docs/TESTING.md) | test suites and results |
| [HARDWARE_TESTING](docs/HARDWARE_TESTING.md) | in-car checklist, Suzuki info gathering |
| [PERFORMANCE](docs/PERFORMANCE.md) | budget and measurements |
| [SECURITY](docs/SECURITY.md) | permissions, privacy, signing |
| [REPOSITORY_RESEARCH](docs/REPOSITORY_RESEARCH.md) | what was learned from other launchers |
