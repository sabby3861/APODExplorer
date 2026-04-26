# APODExplorer

A small iOS app for NASA's Astronomy Picture of the Day. Built for the JPMorgan Chase iOS take-home.

Targets iOS 18. No third-party dependencies. Swift 6 with strict concurrency. Swift Testing for the test suite.

## Running it

Open `APODExplorer.xcodeproj` in Xcode 16+, pick an iOS 18 simulator, hit Run. `⌘U` to run tests.

The default API key is NASA's `DEMO_KEY`, which is rate-limited (30 requests/hour, 50/day per IP) but fine for evaluation. If you hit the limit, grab a free key from [api.nasa.gov](https://api.nasa.gov) — it takes about 60 seconds — and pass it into `DefaultAPODService` in `AppDependencies`. In a real codebase I'd inject this via a gitignored `Secrets.plist`; for a take-home it's inline.

## Shape of the code

```
App/              entry point + composition root
Core/
  Models/         APOD, APODDate, errors, the DTO
  Networking/     URLSession seam + NASA service
  Persistence/    metadata JSON + LRU image cache
  Repository/     the bit that owns offline fallback
Features/
  Today/          view, view model, date picker
  Shared/         MediaView (image/video branch)
  Browse/         stubbed second tab
PreviewContent/   DEBUG-only mocks for SwiftUI previews
```

The architecture is MV with `@Observable`. The view model holds state as an enum (`idle`/`loading`/`loaded`/`failed`). The repository owns the offline-fallback rule — the view model just asks for an APOD and renders whatever comes back.

Protocols are named as nouns (`APODRepository`, `APODService`, `APODMediaCache`), concrete implementations are prefixed `Default` (`DefaultAPODRepository`, etc). This matches how UIKit and Foundation name their protocols (`URLSessionDelegate`, `UITableViewDataSource`) and reads more naturally than the `-ing` / `-able` suffix pattern.

I thought about Clean Architecture with a UseCase layer. For a two-endpoint app with one real piece of business logic it's ceremony, so I didn't build it. If the domain grew — favorites, sync, offline writes — I'd reach for it then.

## How caching works

Brief says "last service call including image should be cached and loaded if any subsequent service call fails." Translated:

- On network success, persist the APOD and the image bytes. Return fresh.
- On network failure, return the cached APOD *only* if its date matches what was requested. Serving yesterday's picture while pretending it's today's would be worse than showing an error.
- If `NWPathMonitor` already reports we're offline, skip the network attempt entirely and go straight to cache — turns a 15-second timeout into an instant response.
- Images use an LRU cache capped at 50MB. APOD images run 4K and I didn't want cache size to grow unbounded. The LRU index rebuilds from disk on startup so files from previous sessions remain managed.

That date-matching guard is the one cache behaviour I'm proudest of. Easy to miss on a first read of the brief.

## Video handling

NASA returns two kinds of video URL: direct playable (MP4 etc.) and embedded (YouTube, Vimeo). AVPlayer can't play YouTube URLs, so there's a host-based branch to WKWebView for embeds. The Oct 11 2021 example from the brief is a YouTube embed — without this branch it wouldn't play.

Two video-rendering bugs I caught in audit and fixed:

1. `AVPlayer` was being recreated on every SwiftUI body evaluation, which restarted the video on any upstream state change. Fixed by holding it in `@State` and only swapping the item when the URL actually changes.
2. `WKWebView` was re-loading the embed URL on every `updateUIView`. Fixed by tracking the last-loaded URL in the coordinator.

These are the sort of bugs you only catch by actually running the thing, not just reading the code.

## Accessibility

- Dynamic Type: all text uses semantic fonts. No fixed sizes.
- VoiceOver: every meaningful element has a label. Decorative icons are hidden.
- Dark Mode: system semantic colours throughout.
- Contrast: same — system colours respect Increase Contrast automatically.

The SwiftUI Previews cover Dark Mode and the XXXL Dynamic Type size as explicit variants, so the bonus requirements can be verified visually without running the simulator.

## Testing

Swift Testing. Suites for:

- `APODRepository` — the offline fallback rule, including the date-mismatch edge case. Most important suite in the project.
- `APODMediaCache` — LRU eviction, key determinism.
- `APODResponseDTO` — wire format + mapping, including rejection of malformed input.
- `APODDate` — range validation.
- `TodayViewModel` — state machine transitions.

No UI tests. At this scope they're more brittle than useful, and the accessibility requirements are better verified in Accessibility Inspector than XCUITest.

One honest gap: the WKWebView rendering path for embedded videos isn't unit-tested. That needs an integration test on-device. The URL heuristic that routes to it is tested.

## What I deliberately didn't build

- **A generic API client** (`Endpoint<T>`, `APIClient.execute(_:)`, that shape). Earns its keep at three-plus endpoints with shared concerns like auth and retry. With one endpoint it's pattern-for-its-own-sake. Current shape would refactor cleanly if the API grew.
- **A DI framework.** Constructor injection through the composition root handles ~20 files without breaking a sweat.
- **Retry with backoff.** The user's Retry button is the retry policy. Automatic retries on a single-image fetch would mostly drain battery.
- **Image zoom / pinch / share sheet.** Not in the brief. Would ship in Round 2 if asked.

## If I had another day

- Pinch-to-zoom on the image.
- Build out the Browse tab as a calendar grid with range loading.
- Add `MetricKit` for real user perf (time-to-first-image is the number that matters).
- Swap the WKWebView embed for a more testable abstraction.

## Contact

Sanjay Kumar — [github.com/sabby3861](https://github.com/sabby3861)
#

