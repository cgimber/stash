import Testing
import CoreLocation
@testable import Stash

@Suite("In-memory spot repository")
@MainActor
struct InMemorySpotRepositoryTests {

    @Test("Starts empty by default")
    func startsEmpty() throws {
        let repository = InMemorySpotRepository()
        #expect(try repository.fetchAll().isEmpty)
    }

    @Test("Can be seeded with fixtures")
    func seededWithFixtures() throws {
        let spot = Spot(
            name: "Fixture",
            type: .pointBreak,
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0)
        )
        let repository = InMemorySpotRepository(spots: [spot])
        #expect(try repository.fetchAll().count == 1)
    }

    @Test("Save inserts a new spot")
    func saveInsertsNewSpot() throws {
        let repository = InMemorySpotRepository()
        let spot = Spot(
            name: "New",
            type: .beachBreak,
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0)
        )
        try repository.save(spot)
        #expect(try repository.fetchAll().count == 1)
    }

    @Test("Save on an existing id updates it and advances updatedAt")
    func saveUpdatesExisting() async throws {
        let spot = Spot(
            name: "Original",
            type: .beachBreak,
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0)
        )
        let repository = InMemorySpotRepository(spots: [spot])
        let originalUpdatedAt = spot.updatedAt

        try await Task.sleep(for: .milliseconds(10))
        spot.name = "Renamed"
        try repository.save(spot)

        let all = try repository.fetchAll()
        #expect(all.count == 1)
        #expect(all.first?.name == "Renamed")
        #expect(spot.updatedAt > originalUpdatedAt)
    }

    @Test("Delete removes a spot")
    func deleteRemovesSpot() throws {
        let spot = Spot(
            name: "Doomed",
            type: .reefBreak,
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0)
        )
        let repository = InMemorySpotRepository(spots: [spot])
        try repository.delete(spot)
        #expect(try repository.fetchAll().isEmpty)
    }

    @Test("Save validates before storing")
    func saveValidates() throws {
        let repository = InMemorySpotRepository()
        let invalidSpot = Spot(
            name: "",
            type: .beachBreak,
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0)
        )
        #expect(throws: StashError.invalidName) { try repository.save(invalidSpot) }
        #expect(try repository.fetchAll().isEmpty)
    }
}
