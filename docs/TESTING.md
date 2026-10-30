# Testing

## Suites

| Suite | Location | Runs on | Count |
|---|---|---|---|
| Dart unit tests | `test/unit/` | host (`flutter test`) | 52 |
| Widget tests | `test/widget/` | host (`flutter test`) | 19 |
| Native JUnit tests | `android/app/src/test/` | host JVM (`./gradlew :app:testDebugUnitTest`) | 4 |
| Integration test | `integration_test/` | emulator or device, real platform channels | 1 flow |

### Unit (`test/unit/`)

- **speed:**
  - EMA smoothing
  - 3 s staleness
  - network fixes ignored
  - accuracy gating
  - status precedence (unavailable → permission → GPS off)
  - km/h and mph conversion
  - native fix-age handling
- **settings:** missing or corrupt blob gives defaults; full round trip; one bad field (enum, URL, list) falls back
  on its own.
- **media selection:**
  - ranking
  - user choice
  - sticky current source
  - remembered app tie-break
  - position extrapolation and clamping
  - action bitmask
- **apps:** sorting; filtering by label or package; hidden apps; favourites first; `findApp` fallback to the same
  package; id parsing.
- **navigation:**
  - haversine; route progress (remaining distance, ETA, next maneuver); off-route distance
  - OSRM parsing; `maneuverText`
  - state machine with fakes: no fix → unavailable; no results; offline → error; route → navigate → reroute
    after 3 off-route fixes → arrive → cancel
  - voice thresholds: 500/100 m once each; a late start says only the turn
- **misc:**
  - capability status and native error-code mapping; tolerant `DeviceReport` parsing
  - sunrise/sunset phases
  - dashboard geometry (presets, compact fallback, portrait, hidden widgets)
  - essential-notification filter
  - all formatters

### Widget (`test/widget/app_test.dart`)

These tests use the real app shell (`SwiftDriveApp`) and real screens, with every platform repository replaced
by the fakes in `test/fakes/fakes.dart`. The fakes are never imported by `lib/`.

- Dashboard at **1024×600, 1280×720, 1280×800, 1920×720** and phone portrait: no overflow, and Settings is
  reachable from the dock.
- Instant theme switch. First run shows onboarding, and *Skip* persists onboarding as done.
- Media card: no-access state links to settings; a playing session shows metadata and sends pause/next.
- Speed card: acquiring → 36 km/h from a 10 m/s fix; GPS-off state with a *Turn on* action.
- Weather: no location; fetch for the position; offline with no cache.
- Drawer search and launch; a Settings toggle persists to storage; Diagnostics lists capabilities and exports
  JSON.
- Lifecycle: native streams are cancelled in the background, and notification contents are dropped when hidden.

The embedded map is disabled in widget tests because MapLibre is a native platform view. It is covered by the
emulator run.

### Native (`ChannelContractTest.kt`)

- Kotlin exceptions map to the error codes that Dart's `PlatformFailure.kindForCode` expects.
- No head-unit adapter reports a vehicle feature as AVAILABLE.
- The Suzuki adapter is not selected until verified.

### Integration (`integration_test/app_flow_test.dart`)

This runs on a real device or emulator against the real Kotlin layer, with prefs cleared first. The flow:
1. Onboarding → Skip → dashboard. The live map loads.
2. Drawer lists real installed apps.
3. Launching a missing package returns a typed `activityMissing` failure.
4. Diagnostics runs the real capability detector.
5. Theme switch, then the persisted settings are re-read as a cold start would.

Launching another app is not automated because it would send the test to the background. That step is checked
by hand.

## Commands

```bash
flutter analyze
```

```bash
flutter test
```

```bash
flutter test integration_test -d emulator-5554
```

Run the native tests from `android/` with `./gradlew :app:testDebugUnitTest`. Set `JAVA_HOME` to a JDK 17+, for
example Android Studio's `jbr` folder.

## Results

Run on 2026-10-30, Windows 11, Flutter 3.47.5:
- `flutter analyze`: no issues.
- `flutter test`: 71 passed, 0 failed.
- JUnit: 4 passed, 0 failed.
- Integration (emulator `SwiftDrive_HU_1280x800`, API 28): see the final report in the commit history.

The phone (vivo V2413) was not used for the integration test because it was locked, and USB debugging later
disconnected.
