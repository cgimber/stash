import Foundation
import SwiftData

@MainActor
final class SwiftDataSpotRepository: SpotRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchAll() throws -> [Spot] {
        try modelContext.fetch(FetchDescriptor<Spot>())
    }

    func save(_ spot: Spot) throws {
        try spot.validate()

        if spot.modelContext == nil {
            modelContext.insert(spot)
        } else {
            spot.updatedAt = .now
        }

        try modelContext.save()
    }

    func delete(_ spot: Spot) throws {
        modelContext.delete(spot)
        try modelContext.save()
    }
}
