# Hardware testing

Nothing in this document has been run on a car yet. The checklist is for the first install on a real head unit,
including the 2026 Suzuki Swift GLX CVT (Pakistan).

## Safety rules

- Install, configure and test **while parked**, with the handbrake on and the engine running or ACC on.
- Keep the factory launcher reachable. Before making SwiftDrive the default HOME, open Settings → Launcher in
  SwiftDrive and check that the factory launcher appears under *Return to factory launcher*.
- Never test reverse camera behaviour by reversing in traffic. Engage reverse while stationary in an empty lot.
- Do not adjust anything in SwiftDrive while driving. Speed and navigation checks need a passenger.

## 1. Collect device information (USB or Wi-Fi ADB, parked)

Head units often hide Developer options: tap *Build number* 7 times, or use the vendor's "factory settings"
password. Connect ADB, then save the output of:

```bash
adb shell getprop > swift_getprop.txt
```

```bash
adb shell pm list packages -f > swift_packages.txt
```

```bash
adb shell dumpsys media_session > swift_media_session.txt
```

```bash
adb shell cmd package query-activities -a android.intent.action.MAIN -c android.intent.category.HOME > swift_home.txt
```

```bash
adb shell dumpsys display | grep -i -E "mDisplayInfo|density" > swift_display.txt
```

Also export SwiftDrive's own report: Settings → Device diagnostics → *Include extra details* → *Export report
(JSON)*.

From these files, record:
- `ro.product.manufacturer`, `ro.product.model`, `ro.product.device`, `ro.build.fingerprint` and the Android
  version. These are needed before `SuzukiSwiftAdapter.matches()` can return true.
- Package names of the factory radio, phone/Bluetooth, vehicle settings and camera apps.
- Whether the radio app publishes a media session (in `dumpsys media_session`, check whether metadata changes when
  the station changes).
- Screen resolution and density.

## 2. Functional checklist

| # | Check | Expected | Result |
|---|---|---|---|
| 1 | Install the APK; open SwiftDrive from the app list | onboarding, then dashboard | |
| 2 | Diagnostics shows the real capabilities | no "Available" for radio/calling/vehicle data | |
| 3 | Set as default HOME, press HOME | dashboard; Back stays on dashboard | |
| 4 | Settings → Launcher → factory launcher | factory launcher opens | |
| 5 | Remove the default (system Settings → Default apps → Home) | factory launcher is HOME again | |
| 6 | Engage reverse (parked) | factory camera appears over SwiftDrive; it returns afterwards | |
| 7 | Ignition off → on (ACC cycle) | SwiftDrive returns; map not black; GPS reacquires | |
| 8 | Location permission + GPS | map puck; speed after GPS lock; "No recent GPS fix" in tunnels/garages | |
| 9 | GPS speed vs. instrument cluster (passenger) | within a few km/h at steady speed | |
| 10 | Notification access → play music on the factory player and on a phone over Bluetooth | media card shows the session; controls work | |
| 11 | Steering-wheel next/previous while music plays | handled by Android's media routing (SwiftDrive does not intercept) | |
| 12 | Radio shortcut → choose the factory radio app | radio app opens; radio card shows a name only if the app publishes a session | |
| 13 | Phone shortcut → choose the factory Bluetooth phone app | app opens | |
| 14 | Search a destination, route, start (passenger) | banner, voice at 500 m/100 m, reroute after deviating | |
| 15 | Mobile data off | cached weather marked offline; map fallback offers external navigation | |
| 16 | Sunrise/sunset auto theme | switches at local sun times | |
| 17 | 30 min idle on dashboard | no lag, no overheating; Diagnostics debug metrics (profile build) | |

## 3. Reporting

Attach the files from section 1, the diagnostics JSON and the checklist results. With those, an adapter can be
written for the vehicle. Only checks that pass on the real unit may be listed as supported in COMPATIBILITY.md.
