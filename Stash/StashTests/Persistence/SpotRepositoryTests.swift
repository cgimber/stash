import Testing
import SwiftData
import CoreLocation
@testable import Stash

@Suite("SwiftData spot repository")
@MainActor
struct SpotRepositoryTests {

    private func makeRepository() throws -> SwiftDataSpotRepository {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Spot.self, configurations: config)
        let context = ModelContext(container)
        return SwiftDataSpotRepository(modelContext: context)
    }

    @Test("Create persists a spot and fetchAll returns it")
    func createAndFetch() throws {
        let repository = try makeRepository()
        let spot = Spot(
            name: "Playa Hermosa",
            type: .beachBreak,
            coordinate: CLLocationCoordinate2D(latitude: 9.5744, longitude: -84.6289)
        )

        try repository.save(spot)

        let all = try repository.fetchAll()
        #expect(all.count == 1)
        #expect(all.first?.name == "Playa Hermosa")
    }

    @Test("Update advances updatedAt but not createdAt")
    func updateAdvancesUpdatedAtOnly() async throws {
        let repository = try makeRepository()
        let spot = Spot(
            name: "Original",
            type: .beachBreak,
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0)
        )
        try repository.save(spot)

        let createdAt = spot.createdAt
        let updatedAtAfterCreate = spot.updatedAt

        try await Task.sleep(for: .milliseconds(10))

        spot.name = "Updated"
        try repository.save(spot)

        #expect(spot.createdAt == createdAt)
        #expect(spot.updatedAt > updatedAtAfterCreate)
    }

    @Test("Delete removes the spot")
    func deleteRemovesSpot() throws {
        let repository = try makeRepository()
        let spot = Spot(
            name: "To Delete",
            type: .reefBreak,
            coordinate: CLLocationCoordinate2D(latitude: 1, longitude: 1)
        )
        try repository.save(spot)
        #expect(try repository.fetchAll().count == 1)

        try repository.delete(spot)

        #expect(try repository.fetchAll().isEmpty)
    }

    @Test("Duplicate names and duplicate coordinates are both allowed")
    func duplicatesAllowed() throws {
        let repository = try makeRepository()
        let coordinate = CLLocationCoordinate2D(latitude: 5, longitude: 5)
        let first = Spot(name: "Same Name", type: .beachBreak, coordinate: coordinate)
        let second = Spot(name: "Same Name", type: .beachBreak, coordinate: coordinate)

        try repository.save(first)
        try repository.save(second)

        #expect(try repository.fetchAll().count == 2)
    }

    @Test("Saving an invalid spot throws and does not persist")
    func invalidSpotSaveFails() throws {
        let repository = try makeRepository()
        let spot = Spot(
            name: "",
            type: .beachBreak,
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0)
        )

        #expect(throws: StashError.invalidName) { try repository.save(spot) }
        #expect(try repository.fetchAll().isEmpty)
    }

    @Test("Unique ID constraint merges spots sharing an id into a single record")
    func uniqueIDConstraintHolds() throws {
        // SwiftData's @Attribute(.unique) upserts on a matching id rather than
        // throwing a constraint violation — confirming no duplicate row is created.
        let repository = try makeRepository()
        let id = UUID()
        let first = Spot(
            id: id,
            name: "First",
            type: .beachBreak,
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0)
        )
        try repository.save(first)

        let second = Spot(
            id: id,
            name: "Second",
            type: .pointBreak,
            coordinate: CLLocationCoordinate2D(latitude: 1, longitude: 1)
        )
        try repository.save(second)

        #expect(try repository.fetchAll().count == 1)
    }
}
