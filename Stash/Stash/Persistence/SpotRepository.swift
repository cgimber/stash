import Foundation

/// SwiftData's ModelContext is main-actor-bound for UI-driven CRUD (spec §2.3),
/// so this protocol and both its implementations are main-actor isolated.
@MainActor
protocol SpotRepository {
    func fetchAll() throws -> [Spot]

    /// Validates, then inserts (new spot) or updates (existing spot, bumping `updatedAt`).
    func save(_ spot: Spot) throws

    func delete(_ spot: Spot) throws
}
