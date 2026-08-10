import Testing
import CoreLocation
@testable import Stash

@Suite("Unit conversion and formatting")
struct UnitConversionTests {

    // MARK: Round trip

    @Test("Feet to meters and back round-trips without meaningful precision loss")
    func feetToMetersRoundTrip() {
        let feet = 12.0
        let meters = Measurement(value: feet, unit: UnitLength.feet).converted(to: .meters)
        let backToFeet = meters.converted(to: .feet)
        #expect(abs(backToFeet.value - feet) < 0.0001)
    }

    // MARK: Imperial formatting

    @Test("Imperial single value has no decimal")
    func imperialWholeNumber() {
        #expect(UnitSystem.imperial.format(feet: 3) == "3 ft")
    }

    @Test("Imperial formatting never shows a decimal across the 1-30 ft range")
    func imperialNeverDecimal() {
        for feet in stride(from: 1.0, through: 30.0, by: 1.0) {
            #expect(!UnitSystem.imperial.format(feet: feet).contains("."))
        }
    }

    // MARK: Metric formatting

    @Test("Metric formatting always shows one decimal")
    func metricOneDecimal() {
        #expect(UnitSystem.metric.format(feet: 3) == "0.9 m")
        #expect(UnitSystem.metric.format(feet: 10) == "3.0 m")
    }

    @Test("Metric formatting always has exactly one digit after the decimal across the range")
    func metricAlwaysOneDecimalDigit() {
        for feet in stride(from: 1.0, through: 30.0, by: 1.0) {
            let formatted = UnitSystem.metric.format(feet: feet)
            let digitsAfterDecimal = formatted.split(separator: ".").last?.prefix(while: \.isNumber).count
            #expect(digitsAfterDecimal == 1)
        }
    }

    // MARK: Ranges

    @Test("Imperial range formatting")
    func imperialRangeFormatting() {
        #expect(UnitSystem.imperial.formatRange(minFeet: 3, maxFeet: 5) == "3–5 ft")
    }

    @Test("Metric range formatting")
    func metricRangeFormatting() {
        #expect(UnitSystem.metric.formatRange(minFeet: 3, maxFeet: 5) == "0.9–1.5 m")
    }

    // MARK: The invariant — spec §4.1, §13

    @Test("Formatting in either unit system never mutates the spot's stored feet values")
    func togglingUnitsDoesNotMutateStorage() throws {
        let spot = Spot(
            name: "Test Spot",
            type: .beachBreak,
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0)
        )
        spot.swellSizeMinFt = 3
        spot.swellSizeMaxFt = 5

        _ = UnitSystem.metric.formatRange(minFeet: spot.swellSizeMinFt!, maxFeet: spot.swellSizeMaxFt!)
        _ = UnitSystem.imperial.formatRange(minFeet: spot.swellSizeMinFt!, maxFeet: spot.swellSizeMaxFt!)
        _ = UnitSystem.metric.format(feet: spot.swellSizeMinFt!)
        _ = UnitSystem.imperial.format(feet: spot.swellSizeMinFt!)

        #expect(spot.swellSizeMinFt == 3)
        #expect(spot.swellSizeMaxFt == 5)
    }
}
