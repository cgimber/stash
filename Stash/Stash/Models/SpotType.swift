import Foundation

enum SpotType: String, CaseIterable, Codable, Identifiable, Sendable {
    case beachBreak = "beach_break"
    case reefBreak = "reef_break"
    case pointBreak = "point_break"

    var id: String { rawValue }
}
