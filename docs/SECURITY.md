# Security and privacy

## Permissions

| Permission | Used for | Requested when |
|---|---|---|
| `INTERNET`, `ACCESS_NETWORK_STATE` | map tiles, weather, routing, search | install time (normal) |
| `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION` | map position, GPS speed, weather, routing | when the user taps *Allow* in onboarding, Settings or the speed card |
| `BLUETOOTH` (≤ API 30) / `BLUETOOTH_CONNECT` | names of connected phone/audio devices | only from Settings → Permissions |
| Notification listener (special access) | media sessions and the notification list | the user enables it in system Settings; SwiftDrive only opens that page |

These permissions are deliberately absent:
- `QUERY_ALL_PACKAGES`. The `<queries>` block lists only the intents needed: LAUNCHER, HOME, `geo:`, DIAL, TTS,
  PROCESS_TEXT, and the Play Services package for detection.
- Background location, foreground services, `RECEIVE_BOOT_COMPLETED`, accessibility services, overlays and
  device admin.
- Root, hidden APIs, reflection into system services, vendor broadcasts and CAN bus access.

## Data handling

- **Notifications.** They stay in memory only. Each one is reduced to title (≤ 60 chars) and text (≤ 120 chars).
  Notifications marked SECRET are skipped, and PRIVATE ones are shown only through their public version. Nothing
  is written to disk, logged or sent over the network. The list is cleared from Dart state whenever the launcher
  leaves the foreground.
- **Location.** It is used only while the launcher is in the foreground and is never stored. It leaves the device
  only in these cases:
  - Weather requests send coordinates rounded to 2 decimals (about 1 km) to Open-Meteo.
  - A route request sends start and destination to the routing server (FOSSGIS OSRM by default).
  - Nominatim receives the typed search text and a proximity hint.
- **Logs.** A 500-entry in-memory ring buffer. The code never logs coordinates, notification text or media
  titles. Export happens only when the user picks a destination file (Storage Access Framework).
- **Diagnostics export.** Device model, SDK and capability states. The build fingerprint and installed-package
  list are included only when the user turns on *Include extra details*.
- **Settings and weather cache.** Stored in app-private `SharedPreferences`.

## Network endpoints

All endpoints are HTTPS and can be changed in Settings. The defaults are free services, suitable for
**personal / non-commercial** use, with no API keys:
- Map styles: `tiles.openfreemap.org`
- Weather: `api.open-meteo.com`
- Routing: `routing.openstreetmap.de` (FOSSGIS)
- Search: `nominatim.openstreetmap.org`. Requests carry a descriptive User-Agent, run at most once per second and
  only on submit, never as autocomplete.

URLs entered in Settings must be `http(s)`, and stored settings are validated field by field.
`settings_test.dart` covers this, for example by rejecting a `javascript:` URL.

## Signing

- Release signing reads `android/key.properties`, which is gitignored together with `*.jks` and `*.keystore`:

  ```properties
  storeFile=upload-keystore.jks      # relative to android/
  storePassword=...
  keyAlias=upload
  keyPassword=...
  ```

- Create the keystore yourself with
  `keytool -genkey -v -keystore android/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`.
- Without `key.properties`, Gradle prints a warning and signs the release APK with the **debug key**. That APK is
  fine for sideloading your own head unit but must not be distributed. CI always produces such debug-signed
  release APKs.
- No keys, passwords or API credentials are committed.

## Safety

- SwiftDrive never disables, hides or modifies factory apps, and never intercepts the reverse camera or steering
  keys.
- The GPS speed is labelled informational and is never shown when stale.
- Navigation and search interactions are for use while parked or by a passenger.
