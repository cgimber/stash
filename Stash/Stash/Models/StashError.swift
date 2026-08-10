import Foundation

enum StashError: LocalizedError, Equatable, Sendable {
    case invalidName
    case invalidCoordinate
    case invalidSwellRange

    var errorDescription: String? {
        switch self {
        case .invalidName:
            "Enter a name"
        case .invalidCoordinate:
            "That location is invalid."
        case .invalidSwellRange:
            "Swell size must be between 1 and 30 ft, with the minimum no greater than the maximum."
        }
    }
}
