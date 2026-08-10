# CLAUDE.md

## Project

Stash is an iOS app that lets surfers privately record, manage, and revisit their favorite surf spots. Map-centric, single-screen, fully private — all data lives on-device (backed up via the normal encrypted iOS device backup, not a third-party service or account).

This project doubles as a learning vehicle for modern iOS development. Two constraints follow from that and should shape every decision:
- Prefer first-party Apple frameworks over third-party dependencies wherever the tradeoff is close.
- Prefer the idiomatic modern approach (SwiftUI, SwiftData, Swift Testing, async/await) over older patterns, even where the older pattern has more tutorials/examples available.

Full detail lives in [spec.md](spec.md) — this file is a working-agreement summary, not a replacement for it. When in doubt about a requirement, check the spec section referenced below.

## Stack

| Decision | Choice |
|---|---|
| Platform | iOS only (iPhone), portrait only |
| Minimum deployment target | iOS 18.0 per spec (currently set to 18.6 — the lowest floor selectable in Xcode 26.5's SDK; treat as equivalent) |
| Language | Swift 6, strict concurrency |
| UI framework | SwiftUI, with `MKMapView` bridged via `UIViewRepresentable` (the one exception — SwiftUI's native `Map` can't do long-press-for-coordinate or draggable annotations) |
| Map provider | MapKit (`MKHybridMapConfiguration` — satellite + labels), no API key |
| Persistence | SwiftData |
| Photo storage | Filesystem, not the database |
| Architecture | MVVM-lite with a repository layer |
| Testing | Swift Testing (unit) + XCUITest (UI) |

## Dependencies

**Exactly one third-party dependency is approved: ZIPFoundation** (SPM, MIT), for ZIP export/import — Apple has no public unzip API.

Do not add any other dependency (no networking libraries, no image-caching libraries, no DI frameworks) without an explicit decision. See spec §2.2.

## Folder structure

```
Stash/
├── App/            // @main, ModelContainer setup, dependency wiring
├── Models/         // Spot (@Model) and enums (SpotType, CardinalDirection, Tide, UnitSystem)
├── Persistence/     // SpotRepository protocol + SwiftData/in-memory impls, PhotoStore
├── Features/       // One folder per screen/flow: Map, PreviewCard, SpotDetail, SpotForm, Filters, Settings
├── Services/       // LocationService, ExportService, ImportService, AppSettings — no SwiftUI imports
├── DesignSystem/    // Theme, shared components
├── Resources/       // Assets.xcassets
└── Support/         // Info.plist, extensions
```

Tests mirror this structure under `StashTests/` and `StashUITests/`. See spec §3.2 for the full breakdown.

## Architecture rules

- Views never touch `ModelContext` directly. They talk to a `@MainActor` view model, or use `@Query` for read-only lists.
- `SpotRepository` is a **protocol**, with a SwiftData implementation and an in-memory implementation for tests and previews.
- `PhotoStore`, `ExportService`, `ImportService`, `LocationService` are independently testable types with no SwiftUI imports.
- No singletons except `PhotoStore.shared` (it owns a single directory URL). Everything else is injected through the SwiftUI environment.
- Disk I/O (photo write/read, ZIP build/extract, JSON encode/decode) runs off the main actor. Batch import work uses a background `ModelActor`, not the main-actor `ModelContext`.

## The invariant most likely to get broken

**Swell size is always persisted in feet** (`swellSizeMinFt` / `swellSizeMaxFt`), regardless of the user's display unit setting. Unit conversion happens only at the presentation layer (formatter), never in the model. Toggling the units setting must never mutate stored data — this has a dedicated unit test (spec §16.2) and should stay that way. See spec §4.1 and §13.

## Testing

- Swift Testing for logic, repository, and services. XCUITest for critical end-to-end flows.
- Coverage target: 80% on `Models/`, `Persistence/`, `Services/`. No coverage target on `Features/` views — chasing view coverage produces brittle tests.
- Every new SwiftUI view gets `#Preview` blocks backed by `InMemorySpotRepository` with realistic fixtures (empty, one spot, many spots, no photo, no conditions, max-length name). Treat previews as part of the deliverable.
- Ask for tests alongside implementation, not afterward — retrofitted tests tend to just assert whatever the code already does.

## Build & verify

From the `Stash/` directory (where `Stash.xcodeproj` lives):

```bash
xcodebuild -project Stash.xcodeproj -scheme Stash -destination 'platform=iOS Simulator,name=iPhone 17' build
xcodebuild -project Stash.xcodeproj -scheme Stash -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Run `xcrun simctl list devices available` if `iPhone 17` isn't installed on this machine and swap in whatever's available. CLI builds/tests are necessary but not sufficient — also open and run the project in Xcode at every phase boundary. Xcode surfaces a class of error (signing, capabilities, Info.plist, preview crashes) that's invisible from the command line.

## Working habits

- Work one implementation phase at a time (see spec §17 for the phase table) — keep each session's context focused.
- Phases 2 (map) and 3 (create flow) are the hardest — the `UIViewRepresentable` bridge and long-press/drag gesture disambiguation (spec §6.7) are where an unfamiliar Xcode project is most likely to stall. Budget accordingly.
- Never log spot names or coordinates, at any log level — that's exactly the private data the app promises to keep private (spec §15.3).
