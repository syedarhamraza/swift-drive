# Features

**Status:** ✅ implemented and tested (unit/widget tests and/or the emulator); 🟡 partial, with the limitation
noted; ⛔ unsupported by design or until hardware is verified.

| Area | Status | Notes |
|---|---|---|
| Dashboard (map, media, clock/weather, speed, notifications, dock) | ✅ | Presets: balanced, map-focused, media-focused, compact. Automatic compact on small screens; stacked in portrait |
| Dock | ✅ | Built-ins plus pinned apps; reorder/add/remove in Settings → Customise dock. A missing app offers Replace/Remove. Settings is always reachable |
| App drawer | ✅ | Search by label or package, A–Z, favourites first, hide/unhide, pin to dock, assign to a factory role. Refreshes on install/uninstall |
| Factory shortcuts (navigation, music, radio, phone, vehicle settings) | ✅ | The user picks installed apps; each is re-checked before launch |
| Default HOME setup | ✅ | RoleManager dialog (API 29+) or the system Home settings |
| Factory-launcher recovery | ✅ | Lists other HOME apps and launches them directly; written instructions as well |
| Map | ✅ | MapLibre + OpenFreeMap vector styles (light/dark follow the theme), follow/free-pan/recenter, optional heading-up |
| Map fallback | ✅ | Map disabled, or style not loaded within 20 s → card with external navigation |
| Destination search | ✅ | Nominatim, on submit only, rate-limited, results cached |
| Routing and guidance | ✅ | OSRM route, banner with next maneuver/distance/ETA, off-route detection and reroute, arrival |
| Voice prompts | 🟡 | 500 m and 100 m, mute toggle. English and metric only |
| Background navigation | ⛔ | Guidance pauses when SwiftDrive is not in the foreground (no foreground service). Use an external app for that |
| External navigation | ✅ | `geo:` intent to the user's chosen navigation app |
| GPS speed | ✅ | Doppler speed only, gated by accuracy, stale after 3 s, km/h or mph. Labelled informational |
| Media | ✅ | All active media sessions, smart source selection, user source picker, play/pause/next/previous/seek, artwork |
| Notifications | ✅ | Compact list, dismiss, hide non-essential. Memory only |
| Weather | ✅ | Open-Meteo current conditions, cached with timestamp, offline state. Place name only when a Geocoder exists |
| Theme | ✅ | Dark, light, system, or auto by sunrise/sunset (falls back to system without sun data). 5 accents |
| Clock | ✅ | 12/24 h; minute-aligned timer, no per-second rebuilds |
| Bluetooth status | 🟡 | Adapter state and connected A2DP/headset device names. No pairing UI (opens system Bluetooth settings) |
| Phone | 🟡 | Opens the chosen phone app or the dialer. No call control or caller ID (`CallingAdapter` returns unsupported) |
| Radio | 🟡 | Opens the chosen radio app. Shows its media-session metadata only if the app publishes one. Never a guessed frequency |
| Vehicle data, CAN, steering keys, headlights | ⛔ | Not available through public APIs; adapter hooks exist |
| Diagnostics | ✅ | Capability report, device info, in-memory log, JSON export (opt-in extra details), debug frame metrics |
| Settings | ✅ | Appearance, dock, units, map/endpoints, voice, media, notifications, performance mode, diagnostics, reset, about/licences |
| Onboarding | ✅ | 6 pages, skippable; permissions requested only on tap |
| Staged startup | ✅ | Shell, then apps, then media/location, then map, then weather/diagnostics |
| Performance mode | ✅ | No route transitions, no progress-bar animation, half-rate weather refresh |
| Corrupt settings recovery | ✅ | Per-field fallback to defaults |
