import Foundation

enum Tide: String, CaseIterable, Codable, Identifiable, Sendable {
    case low, mid, high, all

    var id: String { rawValue }
}
