import Foundation

enum Fmt {
    // Formatters are expensive to allocate (especially NumberFormatter). A full
    // all-time raw dump can be hundreds of thousands of rows, so we allocate
    // each formatter exactly once and reuse it — this is the difference between
    // a multi-minute hang and a sub-second format pass.
    private static let decimal: NumberFormatter = {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.minimumFractionDigits = 0
        nf.groupingSeparator = ","
        return nf
    }()

    private static let shortDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df
    }()

    private static let dateTimeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df
    }()

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func number(_ value: Double, precision: Int) -> String {
        decimal.maximumFractionDigits = precision
        return decimal.string(from: NSNumber(value: value)) ?? String(format: "%.\(precision)f", value)
    }

    // Unambiguous machine-facing formatter: forced '.' decimal and NO grouping,
    // regardless of device locale. A small LLM can't tell a European "45,7"
    // (forty-five point seven) from "457", so the model-facing digest uses this.
    private static let plainDecimal: NumberFormatter = {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.locale = Locale(identifier: "en_US_POSIX")
        nf.usesGroupingSeparator = false
        nf.minimumFractionDigits = 0
        return nf
    }()

    static func plain(_ value: Double, precision: Int) -> String {
        plainDecimal.maximumFractionDigits = precision
        return plainDecimal.string(from: NSNumber(value: value)) ?? String(format: "%.\(precision)f", value)
    }

    static func value(_ value: Double?, _ spec: QuantitySpec) -> String? {
        guard let value else { return nil }
        return "\(number(value, precision: spec.precision)) \(spec.unitLabel)"
    }

    static func duration(_ interval: TimeInterval) -> String {
        let totalMinutes = Int(interval / 60)
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(minutes)m"
    }

    static func shortDate(_ date: Date) -> String {
        shortDateFormatter.string(from: date)
    }

    static func dateTime(_ date: Date) -> String {
        dateTimeFormatter.string(from: date)
    }

    static func isoTimestamp(_ date: Date) -> String {
        isoFormatter.string(from: date)
    }
}
