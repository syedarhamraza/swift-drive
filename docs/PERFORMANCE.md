# Performance

## Rules the code follows

- **Event-driven motion only.** Transitions run once, for 150–350 ms, when something changes: drawer open and
  close, pager page, new notification, track change, play/pause, next maneuver, ETA pill, recenter button.
  Nothing loops, and there is no blur (`BackdropFilter`), shimmer, parallax or animated gradient. The only
  spinner on the dashboard shows while a card waits for its first data. The clock wakes once per minute
  (aligned to the minute). The media progress bar is extrapolated locally and runs only while the card is
  visible and the session is playing.
- **Performance mode and the system "remove animations" setting** both set `MediaQuery.disableAnimations`, and
  every transition reads its duration through `SdMotion.of`, so all of them become instant.
- **Rebuild scope.** Widgets watch narrow `select`s of providers. The map and each dashboard card sit in their
  own `RepaintBoundary`, so a speed update repaints only the speed card.
- **No polling.** Location, media, notifications, packages, Bluetooth and battery/connection status arrive as native broadcast or callback
  streams. They are subscribed only while the launcher is in the foreground and their startup stage is reached.
  Weather refreshes every 30 min (60 min in performance mode).
- **Staged startup.** First frame first. Apps come next, then media and location, then the map, and weather and
  diagnostics last (see ARCHITECTURE.md).
- **Map location pushes are filtered.** Every pushed fix makes MapLibre animate the puck and the follow camera,
  which redraws the whole map for about a second. A fix is pushed only when the car moved more than 3 m or turned
  more than 10°, plus one keep-alive every 25 s. The keep-alive stops MapLibre greying out the puck after 30 s;
  the plugin does not expose that timeout.
- **Performance mode** also turns off page transitions, the per-second media progress tick and the map compass,
  and doubles the weather refresh interval.

## How it was measured

Profile builds (`flutter build apk --profile`), with the dashboard idle, map enabled, dark theme, and no media
playing. A script runs:
- `am start -W` from a force-stopped process three times (the *TotalTime* column).
- Our own log lines for time from `main()` to first frame and map style load.
- `/proc/<pid>/stat` CPU ticks over 30 s of no input, and the same per thread (`/proc/<pid>/task/*`).
- Flutter frames per 10 s (`PerfMetrics`, shown on Diagnostics in debug and profile builds).
- `dumpsys meminfo`.

## Results (2026-10-30)

| | vivo V2413, Android 16 (phone) | AVD 1280×800, API 28, SwiftShader |
|---|---|---|
| Cold start, `am start -W` TotalTime | 345–402 ms | 1028–1220 ms |
| `main()` → first frame | 48–57 ms | 117–169 ms |
| Map style load (cached) | 21–27 ms | 175–204 ms |
| Idle CPU, no location filter | 13.4 % of one core | – |
| Idle CPU, 3 m / 10° filter, 15 s keep-alive | 7.6 % | 15.9 % |
| Idle CPU, 3 m / 10° filter, 25 s keep-alive | not re-measured | 8.4 % |
| Idle CPU after the 2026 redesign (current) | not re-measured | 7.9 %; frames per 10 s 0 / 49 / 0 / 0 |
| Idle Flutter frames per 10 s | 0 / 95 / 0 / 101 (before filter) | 42 / 0 / 56 / 0 / 0 (current) |
| Memory (PSS) | 256–260 MB: Graphics 82–84, Native ≈ 58, Java ≈ 14 | Java 9.5 MB, Native 31.5 MB (graphics are host-side) |

Per-thread sampling on the emulator shows where the idle CPU goes: about two-thirds is MapLibre's own render
thread (`TextureViewRend`), and the rest is the Android main thread, which runs MapLibre's location animators.
Flutter's UI and raster threads are near zero between bursts. The remaining idle cost is the keep-alive push,
and a parked car now causes one short burst every 25 s.

### Caveats

- The phone numbers are from a profile build signed with the debug key. The user was using the phone during
  the last session, so the 25 s keep-alive was measured on the emulator only. A 12 % reading taken while the phone
  was being touched is discarded.
- The emulator renders with SwiftShader, so its GPU work happens on the host. Its timings are much slower and
  its graphics memory reads 0. Compare the two columns only by trend, not by value.
- vivo throttles app logcat output, so the phone's frame counts were read from the Diagnostics screen.
- No head unit has been measured. Cheap units (4 × Cortex-A7/A53, 1–2 GB RAM) will be slower. Turn on
  Performance mode there, or disable the embedded map.

## APK sizes

| Build | Size |
|---|---|
| `app-release.apk` (arm64-v8a + armeabi-v7a + x86_64) | 83.5 MB |
| `app-arm64-v8a-release.apk` | 30.6 MB |
| `app-armeabi-v7a-release.apk` | 25.4 MB |
| `app-x86_64-release.apk` | 32.4 MB |
| `app-profile.apk` (all ABIs) | 127.3 MB |

Most of the size is MapLibre's native library per ABI. Install the split for your unit's ABI. `adb shell getprop
ro.product.cpu.abilist` lists it.
