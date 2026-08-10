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

extension Spot {
    var type: SpotType {
        get { SpotType(rawValue: typeRaw) ?? .beachBreak }
        set { typeRaw = newValue.rawValue }
    }

    var coordinate: CLLocationCoordinate2D {
        get { CLLocationCoordinate2D(latitude: latitude, longitude: longitude) }
        set {
            latitude = newValue.latitude
            longitude = newValue.longitude
        }
    }

    var swellDirection: CardinalDirection? {
        get { swellDirectionRaw.flatMap(CardinalDirection.init(rawValue:)) }
        set { swellDirectionRaw = newValue?.rawValue }
    }

    var windDirection: CardinalDirection? {
        get { windDirectionRaw.flatMap(CardinalDirection.init(rawValue:)) }
        set { windDirectionRaw = newValue?.rawValue }
    }

    var tide: Tide? {
        get { tideRaw.flatMap(Tide.init(rawValue:)) }
        set { tideRaw = newValue?.rawValue }
    }
}

extension Spot {
    /// Enforced at the model layer, not only the UI, per spec §4.3.
    /// Duplicate names and duplicate coordinates are intentionally allowed.
    func validate() throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...60).contains(trimmedName.count) else {
            throw StashError.invalidName
        }

        guard (-90...90).contains(latitude), (-180...180).contains(longitude) else {
            throw StashError.invalidCoordinate
        }

        switch (swellSizeMinFt, swellSizeMaxFt) {
        case (nil, nil):
            break
        case let (.some(min), .some(max)):
            guard (1...30).contains(min), (1...30).contains(max), min <= max else {
                throw StashError.invalidSwellRange
            }
        default:
            // One set, one nil — must be both or neither.
            throw StashError.invalidSwellRange
        }
    }
}
