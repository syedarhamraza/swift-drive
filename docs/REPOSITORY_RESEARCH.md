# Repository research

Three open-source car launchers were read for ideas before implementation. **No code was copied.** Every line of
SwiftDrive was written for this project.

## A. wpfyorg/car-launcher (AGPL-3.0)

Because of the AGPL licence, only concepts were taken. Nothing was transcribed.

Adopted ideas:
- Read media through `MediaSessionManager.getActiveSessions(listenerComponent)`, which requires a notification
  listener.
- Choose among several sessions by priority: playing over paused, with a remembered app. SwiftDrive's version
  (`selectMediaSession`) adds "user choice wins" and "don't jump away from the current source unless another starts
  playing".
- Arbitrate framework `LocationManager` GPS against network providers.

## B. Breakeridis/open-car-launcher (MIT)

Adopted ideas:
- GPS at 1 Hz with a 0 m distance filter.
- Accuracy gating before trusting speed.

Rejected:
- Vendor radio hacks (private broadcasts and hard-coded package names).
- APK unpacking or bundling of other apps.
- Injecting fake media key events.
- A self-updater that downloads APKs.
- osmdroid with the public OSM MAPNIK tile server, which is against its tile usage policy.

## C. cheRoma/bmw-idrive-launcher (MIT)

Adopted ideas:
- MapLibre in TextureView ("texture mode") as the default, because SurfaceView maps went black after
  sleep/resume on head units. SwiftDrive keeps a Settings toggle to switch it off.
- Map lifecycle handled carefully when resuming.

Rejected:
- `QUERY_ALL_PACKAGES`.
- A root shell.
- Using an accessibility service to hijack input.
- Microntek/MCU vendor broadcasts.
- A reverse SSH tunnel.
- Hidden attribution.

## Resulting rules

1. Use public APIs only. Every vendor feature goes behind a `HeadUnitAdapter` that reports `UNSUPPORTED` or
   `UNKNOWN` until it has been verified on real hardware.
2. Factory apps are launched, never replaced or modified.
3. Free services are used within their published usage policies: User-Agent header, 1 request/s, search on
   submit only, caching.
