# Stash — Product & Technical Specification

**Version 2.0 — iOS native, developer-ready**

---

## 1. Overview

**Stash** is an iOS application that lets surfers privately record, manage, and revisit their favorite surf spots. The app is map-centric, simple by design, and fully private — all data is stored on-device, with manual export/import for backup and transfer.

### 1.1 Product Goals
- Record a surf spot in under 15 seconds (long press → name → type → save).
- Never require an account, network connection, or third-party service.
- Make the map the entire interface. No tab bar, no navigation hierarchy beyond one push.

### 1.2 Project Goals (non-product)
This project doubles as a learning vehicle. Two constraints follow from that:
- **Prefer first-party Apple frameworks** over third-party dependencies wherever the tradeoff is close. Exactly one external dependency is sanctioned (§2.2).
- **Prefer the idiomatic modern approach** (SwiftUI, SwiftData, Swift Testing, async/await) over older patterns, even where the older pattern has more tutorials.

---

## 2. Platform & Technology

### 2.1 Stack

| Decision | Choice | Rationale |
|---|---|---|
| Platform | iOS only (iPhone) | Scoped MVP |
| Minimum deployment target | **iOS 18.0** | Unlocks mature SwiftData, `MapKit` improvements, Swift Testing |
| Orientation | **Portrait only** | Set in target settings. Removes an entire QA axis; the map-plus-bottom-sheet layout has no meaningful landscape story |
| Language | **Swift 6** (strict concurrency: minimal → targeted) | See §2.3 |
| UI framework | **SwiftUI**, with `UIViewRepresentable` bridges where needed | See §2.4 |
| Map provider | **MapKit** (`MKMapView`, satellite/hybrid configuration) | Native, free, no API key, no account, no SDK size cost |
| Persistence | **SwiftData** | See §2.5 |
| Photo storage | Filesystem (not the database) | See §5.3 |
| Architecture | MVVM-lite with a repository layer | See §3 |
| Testing | **Swift Testing** (unit) + **XCUITest** (UI) | See §16 |
| Dependency manager | Swift Package Manager | Built into Xcode |
| Xcode | 16.0+ | Required for iOS 18 SDK |

### 2.2 Dependencies

**Exactly one third-party dependency is approved:**

- **ZIPFoundation** (SPM, MIT license) — ZIP archive creation and extraction for export/import.

*Justification:* Apple provides no public unzip API. A zip *can* be created natively via `NSFileCoordinator(readingItemAt:options:.forUploading)`, but there is no counterpart for extraction, so a library is required for import regardless. Using one library for both directions is simpler than mixing approaches.

No other dependencies should be added without an explicit decision. In particular: no networking libraries, no image-caching libraries, no dependency-injection frameworks.

### 2.3 Concurrency

Set **Swift 6 language mode** with strict concurrency checking. Practically:
- All view models are `@MainActor`.
- Disk I/O (photo write/read, ZIP build/extract, JSON encode/decode) runs off the main actor via `async` functions on non-isolated types or actors.
- SwiftData's `ModelContext` is not `Sendable`. Use the main-actor context for all UI-driven CRUD. For batch work (import), use a background `ModelActor` — see §11.4.

If strict concurrency becomes a blocker during early implementation, it is acceptable to start in Swift 5 language mode and migrate at Phase 5 (§17). Note the decision in the repo if so.

### 2.4 Why SwiftUI + a UIKit map bridge

SwiftUI is the primary UI layer for every screen, sheet, and control. **The map is the one exception.**

SwiftUI's native `Map` view, even in iOS 18, cannot cleanly support two behaviors this spec requires:
1. Long-press on empty map to obtain a coordinate.
2. Drag an existing annotation to reposition it.

Therefore the map is `MKMapView` wrapped in a `UIViewRepresentable` (`SurfMapView`), with a `Coordinator` acting as `MKMapViewDelegate` and owning the gesture recognizers. Everything layered *on top* of the map — floating buttons, preview card, sheets — is plain SwiftUI.

This bridge is a core iOS skill and is deliberately part of the learning scope.

### 2.5 Why SwiftData

Recommended over Core Data and GRDB for this project:

- The data model is a **single entity** with no relationships. SwiftData's limitations (complex migrations, intricate predicates, relationship edge cases) are not reachable at this scale.
- Declarative `@Model` + `@Query` integrates directly with SwiftUI, meaning map pins update automatically when the store changes — no manual refresh plumbing.
- It is the framework Apple is actively investing in; time spent learning it compounds.
- Core Data would mean `NSManagedObject` subclasses, a `.xcdatamodeld` editor, and `NSFetchedResultsController` bridging — significantly more boilerplate for zero benefit here. GRDB would mean hand-writing SQL and change observation.

**Known risk:** SwiftData's schema migration story is weaker than Core Data's. Mitigated by (a) a tiny, stable schema, and (b) the ZIP export acting as a version-independent escape hatch — a user can always export, and a bad migration can be recovered by reinstall + import.

---

## 3. Architecture

### 3.1 Layers

```
SwiftUI Views
      ↕  (@Observable view models, @MainActor)
View Models
      ↕
SpotRepository  ──  protocol-backed, wraps SwiftData ModelContext
      ↕
SwiftData (Spot @Model)          PhotoStore (filesystem)
```

**Rules:**
- Views never touch `ModelContext` directly. They talk to a view model or use `@Query` for read-only lists.
- `SpotRepository` is defined as a **protocol** with a SwiftData implementation and an in-memory implementation for tests and previews.
- `PhotoStore`, `ExportService`, `ImportService`, `LocationService` are separate, independently testable types with no SwiftUI imports.
- No singletons except `PhotoStore.shared` (justified: it owns a single directory URL). Everything else is injected through the SwiftUI environment.

### 3.2 Suggested project structure

```
Stash/
├── App/
│   ├── StashApp.swift                 // @main, ModelContainer setup
│   └── AppEnvironment.swift           // dependency wiring
├── Models/
│   ├── Spot.swift                     // @Model
│   ├── SpotType.swift                 // enum
│   ├── CardinalDirection.swift        // enum
│   ├── Tide.swift                     // enum
│   └── UnitSystem.swift               // enum + conversions
├── Persistence/
│   ├── SpotRepository.swift           // protocol
│   ├── SwiftDataSpotRepository.swift
│   ├── InMemorySpotRepository.swift   // tests + previews
│   └── PhotoStore.swift
├── Features/
│   ├── Map/
│   │   ├── MapScreen.swift
│   │   ├── SurfMapView.swift          // UIViewRepresentable
│   │   ├── SurfMapCoordinator.swift   // MKMapViewDelegate + gestures
│   │   ├── SpotAnnotation.swift
│   │   ├── MapViewModel.swift
│   │   └── MapControlsOverlay.swift
│   ├── PreviewCard/
│   ├── SpotDetail/
│   ├── SpotForm/
│   ├── Filters/
│   └── Settings/
├── Services/
│   ├── LocationService.swift
│   ├── ExportService.swift
│   ├── ImportService.swift
│   └── AppSettings.swift              // @Observable, wraps UserDefaults
├── DesignSystem/
│   ├── Theme.swift                    // colors, spacing, radii
│   └── Components/                    // shared buttons, badges, sheets
├── Resources/
│   └── Assets.xcassets
└── Support/
    ├── Info.plist                     // permission strings
    └── Extensions/
```

Tests mirror this structure under `StashTests/` and `StashUITests/`.

---

## 4. Data Model

### 4.1 SwiftData entity

```swift
import SwiftData
import CoreLocation

@Model
final class Spot {
    #Index<Spot>([\.updatedAt])

    @Attribute(.unique) var id: UUID
    var name: String

    /// Raw value of SpotType. Stored as String for export stability
    /// and predicate simplicity.
    var typeRaw: String

    var latitude: Double
    var longitude: Double
    var surfed: Bool

    /// Filename only (e.g. "A1B2-....jpg"), not a full path.
    /// Full paths break across app reinstalls and device restores.
    var photoFilename: String?

    /// Swell size is ALWAYS persisted in FEET, regardless of the user's
    /// display unit setting. Convert at the presentation layer only.
    var swellSizeMinFt: Double?
    var swellSizeMaxFt: Double?

    var swellDirectionRaw: String?
    var windDirectionRaw: String?
    var tideRaw: String?

    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        type: SpotType,
        coordinate: CLLocationCoordinate2D,
        surfed: Bool = false
    ) {
        self.id = id
        self.name = name
        self.typeRaw = type.rawValue
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.surfed = surfed
        self.createdAt = .now
        self.updatedAt = .now
    }
}
```

Add computed, typed accessors (`var type: SpotType`, `var coordinate: CLLocationCoordinate2D`, etc.) in an extension so call sites never touch raw strings.

**Why raw strings for enums:** SwiftData can persist `RawRepresentable` enums, but storing raw strings guarantees the export format is decoupled from Swift type changes, keeps `#Predicate` expressions simple, and makes a future schema migration trivial.

**Why feet as the canonical unit:** a single storage unit eliminates an entire class of bug where toggling the units setting silently mutates stored data. Imperial is the app default, so feet is the natural canonical choice. Conversion: `1 ft = 0.3048 m`.

### 4.2 Enums

```swift
enum SpotType: String, CaseIterable, Codable, Identifiable {
    case beachBreak = "beach_break"
    case reefBreak  = "reef_break"
    case pointBreak = "point_break"
}

enum CardinalDirection: String, CaseIterable, Codable, Identifiable {
    case n = "N", ne = "NE", e = "E", se = "SE"
    case s = "S", sw = "SW", w = "W", nw = "NW"

    /// Bearing in degrees, for future use (wind arrows, sorting).
    var degrees: Double { ... }
}

enum Tide: String, CaseIterable, Codable, Identifiable {
    case low, mid, high, all
}

enum UnitSystem: String, CaseIterable, Codable {
    case imperial, metric
}
```

### 4.3 Validation rules

These are enforced in the model layer, not only in the UI. `SpotRepository.save` throws on violation.

| Field | Rule | On violation |
|---|---|---|
| `name` | Trimmed length 1–60 characters | Save button disabled; repository throws `.invalidName` |
| `type` | Must be a valid `SpotType` | Save disabled |
| `latitude` | −90.0 … 90.0 | Throws `.invalidCoordinate` |
| `longitude` | −180.0 … 180.0 | Throws `.invalidCoordinate` |
| `swellSizeMinFt` | **1.0 … 30.0 ft** (0.3 … 9.1 m) | Slider bounds prevent |
| `swellSizeMaxFt` | 1.0 … 30.0 ft, and `>= min` | Slider enforces; clamp on set |
| Swell range | Both nil, or both non-nil | Setting one sets the other |
| `photoFilename` | If non-nil, file must exist at render time | Fall back to placeholder; see §14 |

Duplicate names and duplicate coordinates are **explicitly allowed** — surfers legitimately record two spots on the same beach.

---

## 5. Storage & Data Handling

### 5.1 Database

- `ModelContainer` is created in `StashApp` with `Schema([Spot.self])`.
- Default on-disk store location (`Application Support/default.store`).
- Autosave enabled; explicit `context.save()` after each mutating operation so failures surface immediately rather than at an arbitrary later point.
- **The store is included in iOS device backups** (the default — do not set `isExcludedFromBackup`). "Private" here means *no third-party service and no account*, not *no backup*: a user who restores a new iPhone expects their spots to come back, and excluding the store would silently break that expectation. Encrypted iCloud device backup is a reasonable trust boundary for this app. This is separate from cloud **sync**, which remains out of scope (§18).

### 5.2 Settings (UserDefaults)

`AppSettings` is an `@Observable` class wrapping `UserDefaults`.

| Key | Type | Default | Persisted across launches? |
|---|---|---|---|
| `unitSystem` | `UnitSystem` | `.imperial` | **Yes** |
| `hasSeenOnboarding` | `Bool` | `false` | **Yes** |
| Filter: selected spot types | `[SpotType]` | all | **No — in-memory only** |
| Filter: hide surfed | `Bool` | `false` | **No — in-memory only** |
| Last map region | `MKCoordinateRegion` | — | **No — recomputed on launch** |

Filters live in `MapViewModel` and are deliberately *not* persisted, per §9.

### 5.3 Photos

Photos are stored as files, never as database blobs (blobs bloat the store and slow every query).

- **Directory:** `Application Support/Photos/`, created lazily on first write. Marked `isExcludedFromBackup = false` (photos *should* be included in device backups).
- **Filename:** `<spotID>.jpg`. Deterministic, so an orphan sweep is trivial.
- **Processing before write:** downscale so the longest edge ≤ 2048 px, re-encode as JPEG at quality 0.8, strip EXIF location data (privacy — the app is private by design and export files may be shared).
- **Replacement:** overwrite in place, then invalidate the in-memory image cache for that ID.
- **Deletion:** deleting a spot deletes its photo file in the same operation. If the file delete fails, the spot delete still proceeds (the orphan sweep will catch it).
- **Orphan sweep:** on app launch, off the main actor, enumerate `Photos/` and delete any file whose stem is not a known spot ID. Log the count; never surface to the user.
- **In-memory cache:** a small `NSCache<NSString, UIImage>` keyed by spot ID, for smooth scrolling of preview cards. Cleared on memory warning.

### 5.4 Thumbnails

Preview cards and detail headers use different sizes. Generate thumbnails on demand with `UIImage.preparingThumbnail(of:)` rather than storing a second file. Cache the result.

---

## 6. Map Screen (Home)

### 6.1 Composition

`MapScreen` is a `ZStack`:
1. `SurfMapView` (full bleed, ignores safe area)
2. `MapControlsOverlay` (floating buttons, respects safe area)
3. Preview card (bottom, conditional)

### 6.2 Launch state

- On launch, the map **auto-fits all spots** using a bounding box (§6.3).
- If **zero spots exist**, show a default region (see §14, empty state) plus an empty-state prompt.
- If **exactly one spot exists**, center on it at a fixed span of 0.02° (≈2 km) — a raw bounding box on one point produces an absurd zoom.
- Filters reset to defaults on every launch (§9).

### 6.3 Bounding box logic

```
1. Filter spots to those currently visible.
2. If 0 → default region. If 1 → center + fixed span.
3. Union MKMapRect for each spot's MKMapPoint.
4. setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: 80, left: 40,
                                                     bottom: 220, right: 40),
                     animated: false)
5. Clamp resulting span to a minimum of 0.01° to avoid over-zoom on
   tightly clustered spots.
```

Bottom padding of 220 pt reserves room for the preview card.

**Known limitation:** spots spanning the antimeridian (e.g. Fiji + Hawaii) produce a bounding box wrapping the wrong way around the globe. Accepted for MVP; documented in §18.

### 6.4 Map configuration

- `MKMapConfiguration`: **`MKHybridMapConfiguration`** — satellite imagery **with** place labels. Decided. Pure satellite (`MKImageryMapConfiguration`) has no labels, which makes an unfamiliar coastline very hard to read and turns the map into a texture. Labels stay on.
- `showsUserLocation = true` once permission is granted.
- `pointOfInterestFilter = .excludingAll` — reduces clutter and keeps user pins dominant.
- Rotation and pitch: enabled (satellite terrain is more legible with tilt).

### 6.5 Floating controls

| Control | Position | Behavior |
|---|---|---|
| **Locate Me** | Bottom-right | Animates to user location at 0.01° span. Behavior on denied permission: §14 |
| **Filter** | Top-right | Opens filter sheet (`.presentationDetents([.medium])`). Shows a badge dot when any filter is non-default |
| **Settings** | Top-left | Pushes the settings screen |

All controls: 44×44 pt minimum tap target, `.ultraThinMaterial` background, subtle shadow for legibility over bright satellite imagery.

### 6.6 Pins

- Custom `MKAnnotationView` subclass (not `MKMarkerAnnotationView`, which limits styling).
- Differentiated by spot type via **both color and glyph** — color alone fails for colorblind users and is illegible over varied satellite imagery.

| Type | Suggested glyph | Note |
|---|---|---|
| Beach Break | wave / sand icon | Final art from designer |
| Reef Break | coral / rock icon | |
| Point Break | headland icon | |

- **Surfed spots** carry a small checkmark accent. This must remain visible when "hide surfed" is off.
- Clustering: **out of scope for MVP.** Set `clusteringIdentifier = nil`. Revisit if real-world use exceeds ~50 spots in one area.
- Annotation views are reused via `dequeueReusableAnnotationView(withIdentifier:)`.

### 6.7 Gesture disambiguation ⚠️

**This resolves an ambiguity in spec v1.0**, where long-press meant both "create new spot" and "drag existing pin."

| Gesture | Target | Result |
|---|---|---|
| Tap | Pin | Select annotation → preview card slides up |
| Tap | Empty map | Deselect → preview card dismisses |
| Long press (0.5 s) | Empty map | Haptic (`.impact(.medium)`) → tentative pin drops → Add form sheet opens |
| Long press + drag | **Selected** pin | Repositions the pin |
| Long press + drag | **Unselected** pin | Nothing — the touch is absorbed, no new pin is created |

**Implementation:**

1. Attach a `UILongPressGestureRecognizer` (`minimumPressDuration = 0.5`) to the `MKMapView` in the coordinator.
2. Implement `gestureRecognizer(_:shouldReceive touch:)` and return `false` when `touch.view` is, or is a descendant of, an `MKAnnotationView`. **Without this, long-pressing a pin also drops a new spot underneath it.**
3. Set `annotationView.isDraggable = true`. MapKit only permits dragging a *selected* annotation, which gives the correct behavior for free.
4. Handle `mapView(_:annotationView:didChange:fromOldState:)`:
   - `.starting` → `newState = .dragging`, haptic
   - `.ending` → persist new coordinate, `newState = .none`
   - `.canceling` → revert to old coordinate, `newState = .none`

### 6.8 Repositioning feedback

Spec v1.0 saved new coordinates silently. Accidental drags are easy and silently destructive, so:

- On drag end, persist immediately **and** show a transient toast: *"Moved [Spot Name]"* with an **Undo** action.
- Undo restores the previous coordinate. Toast auto-dismisses after 4 seconds.
- Only the most recent move is undoable (no undo stack).

---

## 7. Spot Preview Card

Triggered by selecting a pin. A SwiftUI card animating up from the bottom edge (not a modal sheet — the map must stay interactive behind it).

**Contents:**
- Cover photo thumbnail (leading, ~64×64, rounded) or a type-appropriate placeholder glyph
- Spot name (1 line, truncating tail)
- Spot type badge
- Surfed indicator, if surfed
- Chevron affordance

**Behavior:**
- Tap card → push `SpotDetailScreen`
- Tap map elsewhere, or swipe card down → dismiss + deselect
- When the card appears, the map animates the selected pin to sit above the card's top edge (offset the center by ~110 pt)

---

## 8. Spot Detail Screen

Read-only view, pushed via `NavigationStack`.

### 8.1 Layout
- Cover photo, full-width, 16:9, or a placeholder block
- Spot name (large title)
- Spot type badge
- Surfed status indicator
- **Conditions** section — each row hidden entirely when its value is nil (do not render "—"; an empty section reads as broken):
  - Swell size — `"3–5 ft"` / `"1.0–1.5 m"`, formatted per the current unit setting
  - Swell direction — `"NW"`
  - Wind direction — `"NE"`
  - Ideal tide — `"Mid"` / `"All Tides"`
- If **all** conditions are nil, show a single muted line: *"No conditions recorded"* with an inline **Add conditions** button that opens the edit form.
- Coordinates, muted, small — tapping copies to clipboard (useful, near-free)
- **Edit** button (toolbar, trailing) → opens the form sheet in edit mode
- **Delete** button (bottom, destructive style) → confirmation dialog

### 8.2 Delete confirmation

`.confirmationDialog` (not `.alert` — the destructive-action idiom on iOS):
- Title: `"Delete \(spot.name)?"`
- Message: `"This cannot be undone."`
- Actions: **Delete** (destructive) / **Cancel**
- On confirm: delete spot + photo file, pop to map, remove pin with animation, show toast *"Deleted [name]"*.

---

## 9. Add / Edit Spot Form

A bottom sheet (`.sheet` with `.presentationDetents([.medium, .large])`, `.presentationDragIndicator(.visible)`).

### 9.1 Fields

| Field | Control | Required | Notes |
|---|---|---|---|
| Spot Name | `TextField` | **Yes** | Autofocused on create. 60-char limit. `.words` capitalization |
| Spot Type | Segmented `Picker` | **Yes** | No default selection on create — forces a deliberate choice |
| Cover Photo | `PhotosPicker` + camera button | No | See §9.4 |
| Swell Size | Dual-thumb range slider | No | **1–30 ft** (0.3–9.1 m), **1 ft step**. Custom control — SwiftUI has no native range slider. See §13 on stepping |
| Swell Direction | Segmented / 8-item grid | No | Tapping the selected item deselects (allows clearing) |
| Wind Direction | Segmented / 8-item grid | No | Same |
| Ideal Tide | Segmented `Picker` | No | Low / Mid / High / All Tides |
| Surfed | `Toggle` | No | Default off |

An 8-item segmented control is too cramped on a 375 pt-wide screen. Use a **2×4 grid of tappable chips**, or a compass-rose selector, for the direction fields.

### 9.2 Behavior
- Save is enabled only when name (trimmed, non-empty) and type are set.
- **Create mode:** Save persists the spot, dismisses the sheet, confirms the pin, selects it, shows the preview card.
- **Edit mode:** Save updates fields, sets `updatedAt = .now`, dismisses, refreshes detail screen.
- **Cancel with no changes:** dismisses immediately. In create mode, removes the tentative pin.
- **Cancel with unsaved changes:** confirmation dialog — *"Discard changes?"* → **Discard** / **Keep Editing**. Also fires on swipe-to-dismiss (use `.interactiveDismissDisabled(hasChanges)` and present the dialog manually).
- Unit changes made in Settings while the form is open apply live to slider labels; underlying value in feet is unchanged.

### 9.3 Coordinates in the form
Create mode uses the long-press coordinate. The form shows it as muted text; it is **not editable via text entry** in the MVP (a lat/lng text field is an error-prone, rarely used input). Repositioning is done by dragging the pin.

### 9.4 Photo capture
- `PhotosPicker` for library (no permission prompt required in iOS 18 — a strong reason to prefer it).
- A separate camera button presents `UIImagePickerController` (or an `AVCaptureSession` wrapper) — this **does** require `NSCameraUsageDescription`.
- After selection: process per §5.3, show the thumbnail with a **Remove photo** affordance.
- Processing runs off the main actor with a spinner over the thumbnail slot; the form stays interactive.

---

## 10. Filters

Presented as a medium-detent sheet from the Filter button.

| Filter | Type | Options | Default |
|---|---|---|---|
| Spot Type | Multi-select chips | Beach / Reef / Point | All selected |
| Hide Surfed Spots | `Toggle` | — | Off |

**Behavior:**
- Applied in real time — pins add/remove from the map as the toggle changes, with the sheet still open.
- A **Reset** button appears when any filter is non-default.
- **Deselecting all spot types** is permitted and yields an empty map with an overlay: *"No spots match your filters"* + a Reset button. Do not silently re-select all.
- After filtering, do **not** re-fit the bounding box — the map jumping around while the user toggles filters is disorienting.
- Filters are session-only; they reset on every cold launch (§5.2).
- **Filters re-evaluate live on edit.** If a spot is edited so that it now matches (or no longer matches) the active filter, its pin appears or disappears immediately, with no special-casing, warning, or animation exception. `@Query` plus a filtered computed property gives this behavior for free — do not add logic to suppress it.

---

## 11. Settings

Pushed from the map screen. A standard SwiftUI `Form`.

| Setting | Type | Default | Behavior |
|---|---|---|---|
| Units | Segmented: Imperial / Metric | Imperial | Applies globally and immediately |
| Location Permission | Row showing current status | — | Taps open `UIApplication.openSettingsURLString` |
| Export Data | Button | — | §12.1 |
| Import Data | Button | — | §12.2 |
| Spot count | Static footer text | — | *"12 spots · 8 photos · 24.1 MB"* |
| About | Version + build number | — | Useful for bug reports |

---

## 12. Export & Import

### 12.1 Export

**Archive structure:**

```
Stash-2026-08-08.zip
├── spots.json
└── photos/
    ├── <uuid>.jpg
    └── <uuid>.jpg
```

**`spots.json` format** (versioned — v1.0 of this spec used a bare array, which leaves no room to evolve):

```json
{
  "schema_version": 1,
  "exported_at": "2026-08-08T14:22:31Z",
  "app_version": "1.0.0",
  "swell_unit": "ft",
  "spots": [
    {
      "id": "550e8400-e29b-41d4-a716-446655440000",
      "name": "Playa Hermosa",
      "type": "beach_break",
      "coordinates": { "lat": 9.5744, "lng": -84.6289 },
      "surfed": true,
      "photo": "550e8400-e29b-41d4-a716-446655440000.jpg",
      "conditions": {
        "swell_size_min": 3.0,
        "swell_size_max": 5.0,
        "swell_direction": "SW",
        "wind_direction": "NE",
        "tide": "mid"
      },
      "created_at": "2026-03-14T08:00:00Z",
      "updated_at": "2026-07-02T11:30:00Z"
    }
  ]
}
```

Notes:
- `swell_unit` is always `"ft"` in v1 and is present so a future version can change canonical units without ambiguity.
- Null optional fields are **omitted** rather than written as `null` (use `JSONEncoder` default behavior with optionals).
- `photo` references a filename inside `photos/`. If the file is missing from the archive, import proceeds with no photo.

**Flow:**
1. Tap Export → progress indicator (blocking sheet if >20 spots).
2. Build a staging directory in `FileManager.default.temporaryDirectory`.
3. Encode JSON; copy photo files.
4. Zip via ZIPFoundation to `Stash-YYYY-MM-DD.zip`.
5. Present `ShareLink` / `UIActivityViewController`.
6. Delete the staging directory and the temp ZIP after the share sheet dismisses (both success and cancel).

All of steps 2–4 run off the main actor.

### 12.2 Import

**Flow:**
1. Tap Import → `.fileImporter` limited to `[.zip]`.
2. Copy the selected file into the temp directory (security-scoped URL — call `startAccessingSecurityScopedResource()` and pair with a `defer` stop).
3. Unzip to a staging directory.
4. Validate (§12.3).
5. Determine conflicts by `id`.
6. If conflicts exist, present the resolution sheet (§12.4).
7. Apply changes in a single transaction on a background `ModelActor`.
8. Copy photos into `Application Support/Photos/`.
9. Show a summary: *"Imported 8 spots · 3 replaced · 1 skipped."*
10. Refresh the map and re-fit the bounding box.
11. Clean up staging directories.

### 12.3 Import validation

Reject the whole archive on:
- Not a readable ZIP
- No `spots.json` at the archive root
- `spots.json` is not valid JSON
- `schema_version` missing, or greater than the app supports → *"This backup was made with a newer version of Stash. Update the app to import it."*

Skip **individual spots** (and report the count) on:
- Missing or empty `name`, or missing `type`
- Unrecognized `type` value
- Missing coordinates, or coordinates out of range
- Malformed `id` (not a UUID)

Degrade gracefully on:
- Unknown enum values in optional fields (`swell_direction`, `tide`) → treat as nil
- `photo` referencing a missing file → import spot without photo
- Missing timestamps → substitute `.now`
- Swell min > max → swap them

**Import must never partially corrupt the store.** Validate the entire archive before writing anything.

### 12.4 Conflict resolution

When an incoming spot's `id` matches an existing spot:

- Present a sheet listing conflicts (name + both `updated_at` values, so the user can tell which is newer).
- Per-conflict actions: **Replace** / **Keep Both** / **Skip**.
- An **Apply to all** toggle at the top — resolving 40 conflicts one at a time is unusable.

**Keep Both semantics** (undefined in v1.0):
- The incoming spot is assigned a **new UUID**.
- Its name gets a numeric suffix if it collides: `"Playa Hermosa (2)"`.
- Its photo is copied under the new UUID's filename.
- The existing spot is untouched.

---

## 13. Units

- **Canonical storage: feet.** Always. See §4.1.
- Display conversion happens in a formatter, not in the model.
- Range: **1–30 ft** (0.3–9.1 m). A recorded spot always has a real wave; 0 ft is not a meaningful entry.
- Imperial: whole feet only — `"3–5 ft"`, `"8–10 ft"`. Never a decimal.
- Metric: one decimal meter — `"0.9–1.5 m"`.
- **The slider steps in 1 ft increments**, in both unit modes; metric labels are derived from those canonical steps and rounded to one decimal. A metric user therefore sees 0.3, 0.6, 0.9, 1.2, 1.5 m… — a clean 0.3 m progression, since 1 ft ≈ 0.3048 m. This is why a single canonical step works for both systems.
- A second, independent metric stepping scale is explicitly rejected: it would create two sources of truth and introduce rounding drift every time the units toggle.
- Because every stored value is a whole number of feet, `swellSizeMinFt` and `swellSizeMaxFt` are always integral — but they remain `Double` in the model and the export schema, so a future version can introduce finer steps without a migration or a schema bump.
- Changing the setting **never mutates stored data**. This is worth a unit test (§16.2).
- Use `Measurement<UnitLength>` + `MeasurementFormatter` rather than hand-rolled math and string interpolation.

---

## 14. Permissions

| Permission | Info.plist key | When requested |
|---|---|---|
| Location (When In Use) | `NSLocationWhenInUseUsageDescription` | First tap of "Locate Me" |
| Camera | `NSCameraUsageDescription` | First tap of the in-form camera button |
| Photo Library | *(none needed)* | `PhotosPicker` requires no permission on iOS 18 |

**Usage strings** (user-facing — write them properly, App Review rejects vague ones):
- Location: *"Stash uses your location to center the map on where you are. Your location is never stored or shared."*
- Camera: *"Stash uses the camera so you can take a photo of a surf spot."*

**Never request permission on launch.** Request contextually, at the moment of use.

---

## 15. Error Handling Strategy

### 15.1 Principles

1. **Never crash on user data.** No force-unwraps, no `try!`, no array subscripting without bounds checks in any code path touching persisted or imported data.
2. **Distinguish user-actionable from silent.** If the user can fix it, tell them what to do. If they cannot, log it and degrade.
3. **Errors are typed.** A `StashError: LocalizedError` enum with `errorDescription` and `recoverySuggestion`. No stringly-typed errors.
4. **Presentation tiers:**
   - **Toast** — transient, non-blocking (save succeeded, spot moved, spot deleted)
   - **Inline** — field-level validation, in-place in the form
   - **Alert** — blocks and requires a decision (import failure, permission needed)
   - **Log only** — `Logger` from OSLog, never surfaced (orphan sweep, cache misses)

### 15.2 Error matrix

| Condition | Detection | User-facing behavior | Tier |
|---|---|---|---|
| Location permission not yet determined | `CLAuthorizationStatus` | System prompt on first "Locate Me" tap | System |
| Location permission denied | Status `.denied` | Alert: *"Location access is off. Turn it on in Settings to center the map on your position."* → **Open Settings** / **Cancel** | Alert |
| Location permission restricted | `.restricted` | Same message, no Settings button (parental controls) | Alert |
| Location fix times out (>10 s) | Timeout task | Toast: *"Couldn't find your location. Try again outdoors."* Button returns to idle | Toast |
| Camera permission denied | `AVAuthorizationStatus` | Alert with **Open Settings**; photo library remains available | Alert |
| Photo processing fails | Throw from `PhotoStore` | Toast: *"Couldn't save that photo."* Spot still saves without photo | Toast |
| Disk full on photo write | `NSFileWriteOutOfSpaceError` | Alert: *"Not enough storage to save this photo."* Spot saves without photo | Alert |
| Photo file missing at render | `FileManager.fileExists` false | Placeholder glyph, no error shown. Clear `photoFilename` and log | Log |
| SwiftData save fails | `try context.save()` throws | Alert: *"Couldn't save. Please try again."* Keep the form open and the data intact — never dismiss and lose input | Alert |
| `ModelContainer` fails to initialize | Throw at app start | Full-screen recovery view: explain, offer **Import from backup** and **Reset app data**. Do **not** crash | Screen |
| Map tiles unavailable (offline) | `mapViewDidFailLoadingMap` | Grey tiles + a small banner: *"Map imagery unavailable offline."* Pins still render at correct positions | Banner |
| Zero spots | Count check | Empty state overlay: *"Long press anywhere on the map to save your first spot."* **This is the app's only onboarding** — there is no coach mark, tour, or first-run sequence. Write and place this copy carefully; it is carrying the entire burden of teaching the core gesture | Overlay |
| Filters exclude everything | Filtered count == 0 && total > 0 | Overlay: *"No spots match your filters."* + **Reset Filters** | Overlay |
| Export: no spots | Count check | Export button disabled with footer: *"Nothing to export yet."* | Inline |
| Export: ZIP creation fails | Throw | Alert: *"Export failed. Please try again."* Delete partial files | Alert |
| Import: file not a ZIP | Throw on open | Alert: *"That file isn't a Stash backup."* | Alert |
| Import: `spots.json` missing | File check | Same message | Alert |
| Import: malformed JSON | Decode throws | Alert: *"This backup file appears to be damaged."* | Alert |
| Import: newer `schema_version` | Version compare | Alert: *"This backup was made with a newer version. Update the app to import it."* | Alert |
| Import: some spots invalid | Per-spot validation | Proceed; summary states *"Imported 8 spots. 2 could not be read."* | Alert |
| Import: security-scoped access denied | `startAccessing...` returns false | Alert: *"Couldn't read that file. Try copying it to Files first."* | Alert |
| Name exceeds 60 chars | On input | Hard-stop input at limit + character counter at 50+ | Inline |
| Name empty/whitespace-only | On input | Save disabled; helper text: *"Enter a name"* | Inline |
| Swell min > max | On slider change | Impossible — clamp thumbs | — |
| Drag pin into invalid coordinate | Range check | Revert to previous position; toast: *"Can't place a spot there."* | Toast |
| Memory warning | `didReceiveMemoryWarning` | Clear image cache | Log |

### 15.3 Logging

Use `os.Logger` with subsystem `com.<you>.stash` and categories `persistence`, `photos`, `map`, `importexport`, `location`. **Never log spot names or coordinates** at any level — that is exactly the private data the app promises to keep private. Log counts and error codes instead.

---

## 16. Testing Plan

### 16.1 Targets

| Target | Framework | Scope |
|---|---|---|
| `StashTests` | Swift Testing (`import Testing`) | Pure logic, repository, services |
| `StashUITests` | XCUITest | Critical end-to-end flows |

Coverage target: **80% on `Models/`, `Persistence/`, and `Services/`.** No coverage target on `Features/` views — chasing view coverage produces brittle tests.

### 16.2 Unit tests

**Units & formatting** (`UnitConversionTests`)
- Feet → meters and back, round-trip precision
- Formatter output for imperial and metric across the full 1–30 ft range
- Imperial output is never decimal: `3.0` → `"3 ft"`
- Metric output is always one decimal: `3 ft` → `"0.9 m"`, `10 ft` → `"3.0 m"`
- Every slider step round-trips: ft → m label → stored ft is lossless
- Whole-number formatting drops trailing zeros: `3.0` → `"3 ft"`, not `"3.0 ft"`
- **Toggling `unitSystem` does not mutate any stored `swellSizeMinFt`/`MaxFt`**

**Validation** (`SpotValidationTests`)
- Name: empty, whitespace-only, 1 char, 60 chars, 61 chars, emoji, RTL text
- Coordinates: ±90/±180 boundaries, out-of-range values, NaN, infinity
- Swell: min > max, negative, below the 1 ft floor, above the 30 ft ceiling, one-nil-one-set

**Filtering** (`SpotFilterTests`)
- Each spot-type subset returns the right spots
- Hide-surfed excludes only surfed spots
- Combined type + surfed filters
- All types deselected → empty result (not "all")
- Empty store → empty result, no crash

**Bounding box** (`MapRegionTests`)
- 0 spots → default region
- 1 spot → centered, fixed span
- 2+ spots → all contained within the rect
- Tightly clustered spots → span clamped to minimum
- Antimeridian case — assert the *documented* (incorrect) behavior so a future fix breaks the test loudly

**Repository** (`SpotRepositoryTests`) — in-memory `ModelContainer`:
```swift
let config = ModelConfiguration(isStoredInMemoryOnly: true)
let container = try ModelContainer(for: Spot.self, configurations: config)
```
- Create, fetch, update, delete
- `updatedAt` advances on update; `createdAt` does not
- Delete removes the associated photo file
- Unique-ID constraint holds
- Save failure surfaces as a thrown error

**Export** (`ExportServiceTests`)
- Encoded JSON matches the §12.1 schema exactly (compare parsed dictionaries, not raw strings)
- Nil optionals are omitted, not `null`
- Photos land in `photos/` with correct filenames
- Empty store → valid archive with an empty `spots` array
- Spot with no photo → no orphan reference

**Import** (`ImportServiceTests`)
- Valid archive → all spots restored with fields intact
- **Round-trip: export → import into an empty store → deep-equal to the original set** (highest-value test in the suite)
- Malformed JSON → typed error, store untouched
- Missing `spots.json` → typed error
- `schema_version: 99` → version error
- One invalid spot among five valid → 4 imported, 1 reported
- Unknown enum value → field nil, spot still imports
- Missing photo file → spot imports without photo
- Conflict: Replace overwrites; Keep Both creates a new UUID and a suffixed name; Skip leaves the original untouched
- Apply-to-all applies the choice uniformly
- Import of a 500-spot archive completes without blocking the main thread

**Photo store** (`PhotoStoreTests`)
- Write, read, overwrite, delete
- Downscaling caps the longest edge at 2048
- EXIF location is stripped
- Orphan sweep deletes unreferenced files and only those
- Missing-file read returns nil rather than throwing

### 16.3 UI tests

Each seeds a known dataset via a launch argument (`-uiTestSeed <fixture>`) and an in-memory store.

1. **Create a spot** — long press map → form appears → enter name → select type → save → pin visible → preview card shows correct name
2. **Save is gated** — form open, save disabled; name only, still disabled; name + type, enabled
3. **View detail** — tap pin → card → detail screen → all fields render
4. **Edit** — detail → Edit → change name → Save → detail reflects change
5. **Delete** — detail → Delete → Cancel keeps it; Delete → Confirm removes pin
6. **Discard guard** — edit a field → Cancel → dialog appears → Keep Editing preserves input
7. **Filters** — deselect Beach Break → beach pins disappear → Reset restores
8. **Empty filter state** — deselect all → overlay appears
9. **Units** — Settings → Metric → detail screen shows meters
10. **Empty state** — zero spots → prompt visible
11. **Accessibility** — VoiceOver labels present on all controls; pins expose name and type

### 16.4 Manual QA matrix

Automation cannot cover these. Run before any TestFlight build.

**Permissions**
- Location: never asked / granted / denied / restricted / revoked mid-session
- Camera: granted / denied / revoked after a photo was already taken

**Devices & display**
- iPhone SE (smallest — the 8-direction grid is at risk here) and iPhone Pro Max
- Light and dark mode over bright satellite imagery
- Dynamic Type at the largest accessibility size — check the preview card and form labels
- Confirm the target is locked to portrait; rotate on device and verify nothing reflows

**Network & state**
- Airplane mode — map tiles absent, app fully functional otherwise
- Slow network — partial tile loading
- Force-quit mid-form — confirm no data corruption
- Backgrounded during export/import

**Data volume**
- 0, 1, 2, 50, 500 spots — check launch time and bounding-box behavior
- A single spot with a very long name (60 chars) in every view
- Spots on both sides of the antimeridian (documented limitation)
- 50 photos — check storage footprint and scroll performance

**Import/export**
- Export → AirDrop to another device → import
- Import a hand-corrupted ZIP
- Import the same file twice (exercises every conflict path)
- Import a ZIP containing 100 photos

### 16.5 Previews

Every SwiftUI view gets `#Preview` blocks backed by `InMemorySpotRepository` with fixtures: empty, one spot, many spots, spot with no photo, spot with no conditions, spot with a maximum-length name. Previews are the fastest feedback loop in Xcode — treat them as part of the deliverable, not an afterthought.

---

## 17. Implementation Plan

Sequenced so each phase produces something runnable. Given the Claude Code learning goal, commit at every phase boundary and keep phases small enough to review in full.

| Phase | Deliverable | Done when |
|---|---|---|
| **0. Setup** | Xcode project, folder structure, `CLAUDE.md`, ZIPFoundation added, git initialized | App builds and launches to a blank screen |
| **1. Model + persistence** | `Spot`, enums, `SpotRepository`, in-memory implementation, unit tests | Repository tests pass; no UI yet |
| **2. Map** | `SurfMapView` bridge, satellite config, pins from seeded data | Hardcoded spots render as pins |
| **3. Create flow** | Long press → gesture disambiguation → form sheet → save → pin | A spot can be created and survives relaunch |
| **4. Read flow** | Preview card, detail screen, navigation | Tap-through works end to end |
| **5. Edit & delete** | Edit mode, discard guard, delete confirmation, pin drag + undo | All CRUD complete |
| **6. Filters & settings** | Filter sheet, settings screen, units toggle | Units change propagates everywhere |
| **7. Photos** | `PhotosPicker`, camera, processing, cache, orphan sweep | Photos persist across relaunch |
| **8. Export/import** | Both services, conflict resolution, full validation | Round-trip test passes |
| **9. Error handling** | Full §15 matrix, empty states, permission alerts | Every row in the matrix manually verified |
| **10. Polish** | Haptics, animations, accessibility labels, Dynamic Type, designer's visual pass | Manual QA matrix clean |

**Phases 2 and 3 are the hardest** and land early on purpose — the `UIViewRepresentable` bridge and gesture disambiguation are where an unfamiliar Xcode project is most likely to stall. Budget accordingly.

### 17.1 Working with Claude Code

Add a `CLAUDE.md` at the repo root containing:
- The stack and the constraint that **no dependency may be added** beyond ZIPFoundation without an explicit decision
- The folder structure from §3.2 and where new files belong
- "Swell size is stored in feet, always" — the single easiest invariant to violate
- "Views never touch `ModelContext` directly"
- The build/test commands to run before declaring work complete
- A note that `#Preview` blocks are required for every new view

Practical habits for this project:
- Work one phase per session; keep the context focused.
- Ask for tests alongside implementation, not afterward — retrofitted tests tend to assert whatever the code already does.
- Build and run in Xcode yourself at every phase boundary. Xcode surfaces a class of error (signing, capabilities, Info.plist, preview crashes) that is invisible from the command line, and diagnosing those is a meaningful part of the learning goal.

---

## 18. Out of Scope for MVP

- Offline map tile caching
- Cloud **sync** across devices (iCloud sync, Drive, Dropbox). Note that iOS *device backup* is deliberately enabled — see §5.1
- Session history / multiple logs per spot
- Social or sharing features
- Surf forecast or conditions integration
- Pin clustering
- iPad and landscape layouts (target is portrait-locked, iPhone only)
- Onboarding beyond the empty state (§15.2)
- Search
- Localization (English only; still use `String(localized:)` so it stays cheap later)
- Widgets, App Clips, Shortcuts
- Antimeridian-spanning bounding boxes (§6.3)
- Editing coordinates via text entry
- Undo beyond the single most recent pin move
- Independent metric slider stepping, and sub-foot swell precision (§13)
- Branding, icon, color palette (designer)

---

## 19. Decision Log

Decisions that were open during spec drafting and are now closed. Recorded with rationale so they don't get relitigated mid-build.

| # | Decision | Resolution | Where it lives |
|---|---|---|---|
| 1 | Map imagery style | **Satellite with labels** (`MKHybridMapConfiguration`). Label-free imagery makes an unfamiliar coastline unreadable | §6.4 |
| 2 | Orientation | **Portrait only.** Removes a full QA axis; no meaningful landscape layout for a map with a bottom sheet | §2.1, §16.4 |
| 3 | Onboarding | **None beyond the empty state.** The zero-spot overlay teaches the long-press gesture and is the only instruction the app gives | §15.2, §18 |
| 4 | iCloud device backup | **Leave enabled.** Privacy here means no account and no third party, not no backup. A device restore must bring spots back | §5.1 |
| 5 | Minimum swell value and step | **Floor of 1 ft** (0.3 m), stepping in **1 ft** increments. A recorded spot always has a wave; whole feet also yield a clean 0.3 m metric progression | §4.3, §9.1, §13 |
| 6 | Edited spot vs. active filter | **Appears/disappears immediately**, no special handling. Falls out of `@Query` for free — do not add suppression logic | §10 |

Earlier decisions carried from the v1.0 → v2.0 rewrite, for the same reason:

| Decision | Resolution | Where |
|---|---|---|
| Map provider | MapKit, not Mapbox — native, free, no account | §2.1 |
| Persistence | SwiftData, not Core Data or GRDB — single entity, SwiftUI-native | §2.5 |
| UI framework | SwiftUI, with `MKMapView` bridged via `UIViewRepresentable` | §2.4 |
| Deployment target | iOS 18.0 | §2.1 |
| Dependencies | ZIPFoundation only; nothing else without an explicit decision | §2.2 |
| Canonical swell unit | Feet, always. Units setting is display-only | §4.1, §13 |
| Long-press disambiguation | Gesture recognizer rejects touches landing on annotation views | §6.7 |
| Pin reposition | Auto-saves, with a 4-second undo toast | §6.8 |
| "Keep Both" on import | Incoming spot gets a fresh UUID and a numeric name suffix | §12.4 |

---

*Spec version 2.0 — Stash, iOS native. Supersedes v1.0 (Surf Spot Mapper, React Native / Expo / Mapbox).*
