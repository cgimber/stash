import Foundation

/// A plain, non-SwiftData fake conforming to SpotRepository, for tests and
/// #Preview fixtures. Deliberately holds Spot instances outside of any
/// ModelContext — see spec §16.5 on seeding previews with realistic fixtures.
@MainActor
final class InMemorySpotRepository: SpotRepository {
    private var spotsByID: [UUID: Spot]

    init(spots: [Spot] = []) {
        self.spotsByID = Dictionary(uniqueKeysWithValues: spots.map { ($0.id, $0) })
    }

    func fetchAll() throws -> [Spot] {
        Array(spotsByID.values)
    }

    func save(_ spot: Spot) throws {
        try spot.validate()

        if spotsByID[spot.id] != nil {
            spot.updatedAt = .now
        }

        spotsByID[spot.id] = spot
    }

    func delete(_ spot: Spot) throws {
        spotsByID.removeValue(forKey: spot.id)
    }
}
