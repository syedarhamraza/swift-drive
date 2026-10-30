# Compatibility

**Status words:** *Verified* means checked on the named device. *Expected* means it relies only on public
Android APIs that should work but has not been seen on that device. *Unknown* means it has not been tested.
No vehicle-specific feature is claimed.

## Requirements

- Android 9 (API 28) or newer. ABIs: arm64-v8a, armeabi-v7a, x86_64.
- Google Play Services are **not** required: map, location, weather, routing and search all work without them.
- A GPS receiver is needed for speed and navigation. The network location provider is used for position only.
- Internet is needed for the map, weather, routing and search. Offline, cached weather is shown as stale and the
  map falls back to an external-navigation card.

## Devices

| Device | Android | Result |
|---|---|---|
| AVD 1280×800 @160 dpi, AOSP image, no Play Services | 9 (API 28) | Verified: onboarding, dashboard, map with OpenFreeMap, injected GPS position, Open-Meteo weather, diagnostics, drawer, theme switch, integration test |
| vivo V2413 (phone) | 16 (API 36) | Debug APK installs and starts (first frame logged). Screens not inspected: the phone was locked |
| Generic Chinese Android head units | 9–13 | Expected. Not tested |
| Suzuki Swift GLX CVT 2026 (Pakistan) head unit | unknown | **Unknown. Not tested.** See HARDWARE_TESTING.md |

## Feature dependencies

| Feature | Needs | Without it |
|---|---|---|
| Default HOME | `RoleManager` (API 29+) or the system Home settings page | Some head units hide the Home picker; launch SwiftDrive from the app list instead |
| Media card | Notification listener access | "Enable access" state |
| Notifications | Notification listener access | "Enable access" state |
| Speed | GPS provider with Doppler speed (`Location.hasSpeed`) | "Acquiring", "No GPS on this device" or "GPS is off" |
| Place names on weather | `Geocoder.isPresent()` (usually needs Play Services) | Weather is shown without a place name |
| Voice guidance | An installed TTS engine | Guidance continues silently (logged) |
| Bluetooth device names | Bluetooth hardware + `BLUETOOTH_CONNECT` | "Not on this device" / permission prompt |
| Map rendering | OpenGL ES 3 | 20 s style timeout → external-navigation fallback. Try Settings → *Map compatibility rendering* |

## Vehicle features (all unsupported until verified)

| Capability | Generic adapter | Suzuki adapter |
|---|---|---|
| FM/AM radio control and frequency | Unsupported: the Radio shortcut opens the user-chosen factory radio app | Unknown |
| Bluetooth calling | Unsupported: the Phone shortcut opens the chosen phone app or the dialer | Unknown |
| Vehicle data (fuel, doors, CAN) | Unsupported. SwiftDrive sends no CAN commands | Unknown |
| Steering-wheel keys | Unknown: Android routes media keys to the active media session, not to SwiftDrive | Unknown |
| Reverse camera | Unknown: handled by the factory system; SwiftDrive does not intercept it | Unknown |
| Headlight state for the theme | Unsupported: the auto theme uses sunrise/sunset instead | Unknown |

## Known head-unit quirks handled

- **Black map after sleep:** MapLibre runs in TextureView mode by default. A Settings toggle switches it back to
  SurfaceView, applied after restart.
- **Location providers on API < 30:** `onStatusChanged`, `onProviderEnabled` and `onProviderDisabled` are
  overridden explicitly to avoid `AbstractMethodError`.
- **Screen sizes:** 1024×600, 1280×720, 1280×800 and 1920×720 are covered by widget tests. Small screens switch
  to the compact layout automatically.
