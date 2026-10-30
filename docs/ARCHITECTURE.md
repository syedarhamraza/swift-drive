# Architecture

SwiftDrive is a Flutter app (UI, state, networking) on top of a thin Kotlin layer that exposes only public Android
APIs. Every Android capability sits behind a Dart interface. The UI never calls a platform channel directly.

```
┌──────────────────────── Flutter (lib/) ────────────────────────┐
│ features/<name>/ui      widgets and screens (ConsumerWidget)   │
│ features/<name>/state   Riverpod Notifiers / providers         │
│ features/<name>/domain  pure logic (speed, routing, selection) │
│ features/<name>/data    repository interface + channel impl    │
│ core/                   theme, settings, logging, failures     │
└───────────────┬────────────────────────────────────────────────┘
                │ MethodChannel + EventChannel per domain
┌───────────────▼──────── Kotlin (android/app/src/main/kotlin) ──┐
│ platform/       AppManager, LauncherBridge, LocationService,   │
│                 MediaManager, NotificationBridge,              │
│                 BluetoothBridge, DeviceDiagnostics             │
│ services/       LauncherNotificationListener                   │
│ compatibility/  CapabilityDetector, HeadUnitAdapter            │
└────────────────────────────────────────────────────────────────┘
```

## Layers

**data/**: one `abstract interface class XRepository` plus a `ChannelXRepository`. Every native call goes through
`guardPlatform()` (`core/platform/platform_failure.dart`). It turns `PlatformException` codes into a typed
`PlatformFailure`. The Kotlin side raises those codes through `Result.guard` / `guardAsync` (`platform/ChannelUtil.kt`):
`PERMISSION_DENIED`, `UNSUPPORTED`, `SERVICE_UNAVAILABLE`, `ACTIVITY_NOT_FOUND`, `SECURITY`, `INTERNAL`.
The JUnit test `ChannelContractTest` pins this contract.

**domain/** holds pure Dart with no Flutter or Riverpod imports, and has unit tests:
- `location/domain/speed.dart`: `SpeedEstimator`, which gates GPS speed and decides its state.
- `media/domain/source_selection.dart`: `selectMediaSession`.
- `navigation/domain/route_geometry.dart`: `RouteTracker`, which does polyline projection, remaining
  distance/ETA and next maneuver.
- `dashboard/domain/dashboard_layout.dart`: `computeDashboardGeometry`, the single layout decision for every
  preset and size.

**state/** uses Riverpod 3 `Notifier`s, written by hand with no code generation. Repositories are plain
`Provider`s, so tests swap them with `overrideWithValue` (see `test/fakes/fakes.dart`).

**ui/** widgets watch narrow `select(...)`ed slices so that a GPS fix does not rebuild the media card, and so on.

## Lifecycle and staged startup

- `main.dart` awaits `SharedPreferences` only, a few ms, so that the first frame already uses the right theme.
- `startupStageProvider` (`core/app_state.dart`) then advances: 2 after the first frame, 3 at +250 ms
  (media, location, notifications), 4 at +700 ms (map), and 5 at +2.5 s (weather, diagnostics).
- `foregroundProvider` is driven by `AppLifecycleListener`. Every native stream provider watches it, so location,
  media, Bluetooth and notification streams are cancelled when the launcher is hidden and re-attached on resume.
  Nothing tracks or polls in the background. A widget test (`native streams stop while the launcher is in the
  background`) checks this.
- `resumeTickProvider` increments on resume, so permission, HOME-role and access checks re-run after the user
  returns from system Settings.

## HOME role and recovery

The manifest declares `MAIN/HOME/DEFAULT` and `MAIN/LAUNCHER` on a `singleTask` activity. The role is requested
only through `RoleManager.createRequestRoleIntent(ROLE_HOME)` (API 29+) or `Settings.ACTION_HOME_SETTINGS` (API 28).
Settings → Launcher lists every other HOME activity and can launch the factory launcher directly. Back leaves the
dashboard only when SwiftDrive is *not* the default HOME.

## Maps and navigation

- `maplibre_gl` is used with a `ManualLocationSource`. The vehicle puck is fed from our own `LocationManager`
  stream, so the plugin needs neither its own location permission nor Google Play Services.
- Map styles: OpenFreeMap liberty and dark.
- Follow mode uses the native tracking mode. A pan dismisses it and shows *Recenter*.
- If the style does not load within 20 s, or the map is disabled, `_MapFallback` offers external navigation via a
  `geo:` intent.
- `NavigationController` is the state machine: idle → searching → calculating → routeReady → navigating ⇄
  rerouting → arrived, plus unavailable and error.
  - Off-route means more than 50 m for 3 consecutive fixes, with at most one reroute every 30 s.
  - Arrival means within 30 m.
- `VoiceGuidance` speaks only maneuvers that OSRM supplied, at 500 m and 100 m.

## Head-unit adapters

`compatibility/HeadUnitAdapter.kt` defines the extension point for vendor features: radio, calling, vehicle data,
steering keys, reverse camera, headlights.
- `GenericAndroidAdapter` reports `UNSUPPORTED`, or `UNKNOWN` where Android may route the feature itself.
- `SuzukiSwiftAdapter` exists but `matches()` returns false until the real head unit has been inspected
  (see HARDWARE_TESTING.md).

On the Dart side, `CallingAdapter` and the radio card read only public media-session data from the user-chosen
factory app.

## Dependencies (deliberately few)

| Package | Why |
|---|---|
| flutter_riverpod | state + DI |
| shared_preferences | settings JSON blob, weather cache |
| http | Open-Meteo, OSRM, Nominatim |
| intl | clock/date formatting |
| maplibre_gl | vector map without Google services |
| flutter_tts | turn-by-turn voice with navigation audio attributes |

The following were not used:
- go_router: there are only five routes.
- freezed and codegen: plain classes are enough.
- drift: there is no relational data.
- permission_handler: the native side already needs permission state.
- path_provider: export goes through SAF.
- pigeon: the channels are small.
