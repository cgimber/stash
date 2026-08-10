import Foundation

enum CardinalDirection: String, CaseIterable, Codable, Identifiable, Sendable {
    case n = "N", ne = "NE", e = "E", se = "SE"
    case s = "S", sw = "SW", w = "W", nw = "NW"

    var id: String { rawValue }

    /// Bearing in degrees, for future use (wind arrows, sorting).
    var degrees: Double {
        switch self {
        case .n: 0
        case .ne: 45
        case .e: 90
        case .se: 135
        case .s: 180
        case .sw: 225
        case .w: 270
        case .nw: 315
        }
    }
}
