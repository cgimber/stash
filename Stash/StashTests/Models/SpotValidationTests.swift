import Testing
import CoreLocation
@testable import Stash

@Suite("Spot validation")
struct SpotValidationTests {

    private func makeSpot(
        name: String = "Playa Hermosa",
        type: SpotType = .beachBreak,
        latitude: Double = 9.5744,
        longitude: Double = -84.6289,
        minFt: Double? = nil,
        maxFt: Double? = nil
    ) -> Spot {
        let spot = Spot(
            name: name,
            type: type,
            coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        )
        spot.swellSizeMinFt = minFt
        spot.swellSizeMaxFt = maxFt
        return spot
    }

    // MARK: Name

    @Test("Empty name is invalid")
    func emptyNameInvalid() {
        #expect(throws: StashError.invalidName) { try makeSpot(name: "").validate() }
    }

    @Test("Whitespace-only name is invalid")
    func whitespaceOnlyNameInvalid() {
        #expect(throws: StashError.invalidName) { try makeSpot(name: "   ").validate() }
    }

    @Test("Single-character name is valid")
    func singleCharacterNameValid() throws {
        try makeSpot(name: "A").validate()
    }

    @Test("60-character name is valid")
    func sixtyCharacterNameValid() throws {
        try makeSpot(name: String(repeating: "A", count: 60)).validate()
    }

    @Test("61-character name is invalid")
    func sixtyOneCharacterNameInvalid() {
        #expect(throws: StashError.invalidName) {
            try makeSpot(name: String(repeating: "A", count: 61)).validate()
        }
    }

    @Test("Emoji name is valid")
    func emojiNameValid() throws {
        try makeSpot(name: "🏄‍♂️ Point").validate()
    }

    @Test("Right-to-left script name is valid")
    func rtlNameValid() throws {
        try makeSpot(name: "نقطة السحب").validate()
    }

    // MARK: Coordinates

    @Test("Positive boundary coordinates (90, 180) are valid")
    func positiveBoundaryCoordinatesValid() throws {
        try makeSpot(latitude: 90, longitude: 180).validate()
    }

    @Test("Negative boundary coordinates (-90, -180) are valid")
    func negativeBoundaryCoordinatesValid() throws {
        try makeSpot(latitude: -90, longitude: -180).validate()
    }

    @Test("Latitude just past the positive bound is invalid")
    func latitudeAbovePositiveBoundInvalid() {
        #expect(throws: StashError.invalidCoordinate) {
            try makeSpot(latitude: 90.1, longitude: 0).validate()
        }
    }

    @Test("Latitude just past the negative bound is invalid")
    func latitudeBelowNegativeBoundInvalid() {
        #expect(throws: StashError.invalidCoordinate) {
            try makeSpot(latitude: -90.1, longitude: 0).validate()
        }
    }

    @Test("Longitude just past the positive bound is invalid")
    func longitudeAbovePositiveBoundInvalid() {
        #expect(throws: StashError.invalidCoordinate) {
            try makeSpot(latitude: 0, longitude: 180.1).validate()
        }
    }

    @Test("Longitude just past the negative bound is invalid")
    func longitudeBelowNegativeBoundInvalid() {
        #expect(throws: StashError.invalidCoordinate) {
            try makeSpot(latitude: 0, longitude: -180.1).validate()
        }
    }

    @Test("NaN coordinate is invalid")
    func nanCoordinateInvalid() {
        #expect(throws: StashError.invalidCoordinate) {
            try makeSpot(latitude: .nan, longitude: 0).validate()
        }
    }

    @Test("Infinite coordinate is invalid")
    func infiniteCoordinateInvalid() {
        #expect(throws: StashError.invalidCoordinate) {
            try makeSpot(latitude: .infinity, longitude: 0).validate()
        }
    }

    // MARK: Swell size

    @Test("Nil swell range is valid")
    func nilSwellRangeValid() throws {
        try makeSpot().validate()
    }

    @Test("Fully specified swell range within bounds is valid")
    func validSwellRangeValid() throws {
        try makeSpot(minFt: 3, maxFt: 5).validate()
    }

    @Test("Min greater than max is invalid")
    func minGreaterThanMaxInvalid() {
        #expect(throws: StashError.invalidSwellRange) {
            try makeSpot(minFt: 5, maxFt: 3).validate()
        }
    }

    @Test("Negative swell size is invalid")
    func negativeSwellInvalid() {
        #expect(throws: StashError.invalidSwellRange) {
            try makeSpot(minFt: -1, maxFt: 5).validate()
        }
    }

    @Test("Swell size below the 1 ft floor is invalid")
    func belowFloorInvalid() {
        #expect(throws: StashError.invalidSwellRange) {
            try makeSpot(minFt: 0.5, maxFt: 5).validate()
        }
    }

    @Test("Swell size above the 30 ft ceiling is invalid")
    func aboveCeilingInvalid() {
        #expect(throws: StashError.invalidSwellRange) {
            try makeSpot(minFt: 3, maxFt: 31).validate()
        }
    }

    @Test("One-nil-one-set swell range is invalid")
    func oneNilOneSetInvalid() {
        #expect(throws: StashError.invalidSwellRange) {
            try makeSpot(minFt: 3, maxFt: nil).validate()
        }
    }
}
