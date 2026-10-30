# Features

**Status:** ✅ implemented and tested (unit/widget tests and/or the emulator); 🟡 partial, with the limitation
noted; ⛔ unsupported by design or until hardware is verified.

| Area | Status | Notes |
|---|---|---|
| Dashboard (map, media, weather, speed, notifications, rail) | ✅ | Rounded rail with clock and GPS state; map; card column; vertical pager (weather, speed, notifications, radio) with dots. Wide screens give the pager its own column. Presets: balanced, map-focused, media-focused, compact; automatic compact on small screens; stacked in portrait |
| Dock (rail) | ✅ | Floats over the map's edge. Top: Wi-Fi/mobile/offline glyph (connection type, not signal strength), battery % with charging state (hidden on units without a battery) and the time. Built-ins as large glyphs (or the chosen app's icon for Music/Phone/Radio; Maps opens the navigation app) plus pinned apps as round icons, with tooltips; reorder/add/remove in Settings → Customise dock. A missing app offers Replace/Remove. Apps and Settings are pinned at the bottom and always reachable |
| App drawer | ✅ | Opens from behind the rail in the map's place, on a static gradient (no blur); the map moves into the cards' place and pushes them off screen. Back closes it. Icons are round, labels one line. First tile exits to the factory launcher. Search by label or package, A–Z, favourites first, page up/down buttons, hide/unhide, pin to dock, assign to a factory role. Refreshes on install/uninstall |
| Factory shortcuts (navigation, music, radio, phone, vehicle settings) | ✅ | The user picks installed apps; each is re-checked before launch |
| Default HOME setup | ✅ | RoleManager dialog (API 29+) or the system Home settings |
| Factory-launcher recovery | ✅ | Lists other HOME apps and launches them directly; written instructions as well |
| Map | ✅ | MapLibre + OpenFreeMap vector styles (light/dark follow the theme), follow/free-pan/recenter, optional heading-up |
| Map fallback | ✅ | Map disabled, or style not loaded within 20 s → card with external navigation |
| Destination search | ⏸ | Hidden: the dashboard map is for orientation only and Maps opens the navigation app. The code (Nominatim, on submit only, rate-limited, cached) is kept |
| Routing and guidance | ⏸ | Unreachable while destination search is hidden.  OSRM route, banner with next maneuver/distance/ETA, off-route detection and reroute, arrival |
| Voice prompts | 🟡 | 500 m and 100 m, mute toggle. English and metric only |
| Background navigation | ⛔ | Guidance pauses when SwiftDrive is not in the foreground (no foreground service). Use an external app for that |
| External navigation | ✅ | `geo:` intent to the user's chosen navigation app |
| GPS speed | ✅ | Doppler speed only, gated by accuracy, stale after 3 s, km/h or mph. Labelled informational |
| Media | ✅ | All active media sessions, smart source selection, user source picker, play/pause/next/previous/seek, artwork |
| Notifications | ✅ | Newest message card with count, Read aloud (TTS, on request only) and Dismiss/Open; full list in a sheet; hide non-essential. Memory only. No reply (needs RemoteInput capture) |
| Weather | ✅ | Open-Meteo current, feels-like, today's high/low, next 5 hours and 3 days in one request; cached with timestamp; offline state; Open-Meteo credit. Place name only when a Geocoder exists |
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
| Full screen | ✅ | Settings → Display. Hides the status and navigation bars (immersive sticky); an edge swipe shows them briefly |
| Performance mode | ✅ | No route transitions, no progress-bar animation, half-rate weather refresh |
| Corrupt settings recovery | ✅ | Per-field fallback to defaults |
