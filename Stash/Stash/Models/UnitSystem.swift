import Foundation

nonisolated enum UnitSystem: String, CaseIterable, Codable, Sendable {
    case imperial
    case metric

    /// The display unit for this system. Storage is always feet — see Spot.swellSizeMinFt/MaxFt.
    var length: UnitLength {
        switch self {
        case .imperial: .feet
        case .metric: .meters
        }
    }

    /// Imperial is whole feet, never a decimal. Metric is always one decimal place.
    private var fractionDigits: Int {
        self == .imperial ? 0 : 1
    }

    /// Formats a single swell height stored in feet, converted to this unit system.
    /// e.g. `UnitSystem.imperial.format(feet: 3)` -> "3 ft", `.metric.format(feet: 3)` -> "0.9 m".
    ///
    /// Uses `.medium` style: `.short` returns the bare symbol with no space (e.g. "3′", "0.9m"),
    /// which doesn't match the spec's desired "3 ft" / "0.9 m" format.
    func format(feet: Double) -> String {
        let measurement = Measurement(value: feet, unit: UnitLength.feet).converted(to: length)
        let formatter = MeasurementFormatter()
        formatter.unitStyle = .medium
        formatter.unitOptions = .providedUnit
        formatter.numberFormatter.minimumFractionDigits = fractionDigits
        formatter.numberFormatter.maximumFractionDigits = fractionDigits
        return formatter.string(from: measurement)
    }

    /// Formats a swell range stored in feet, e.g. "3–5 ft" (imperial) or "0.9–1.5 m" (metric).
    func formatRange(minFeet: Double, maxFeet: Double) -> String {
        // Derive the unit suffix from `format(feet:)` itself, rather than a standalone
        // MeasurementFormatter.string(from: Unit) call — that variant ignores unitStyle
        // and always returns the long form ("meter" instead of "m").
        let maxFormatted = format(feet: maxFeet)
        guard let spaceIndex = maxFormatted.firstIndex(of: " ") else {
            return maxFormatted
        }
        let maxNumber = maxFormatted[..<spaceIndex]
        let unitSuffix = maxFormatted[maxFormatted.index(after: spaceIndex)...]

        let minMeasurement = Measurement(value: minFeet, unit: UnitLength.feet).converted(to: length)
        let numberFormatter = NumberFormatter()
        numberFormatter.minimumFractionDigits = fractionDigits
        numberFormatter.maximumFractionDigits = fractionDigits
        let minString = numberFormatter.string(from: minMeasurement.value as NSNumber) ?? "\(minMeasurement.value)"

        return "\(minString)–\(maxNumber) \(unitSuffix)"
    }
}
