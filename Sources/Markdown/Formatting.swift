import Foundation

enum Fmt {
    static func number(_ value: Double, precision: Int) -> String {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = precision
        nf.minimumFractionDigits = 0
        nf.groupingSeparator = ","
        return nf.string(from: NSNumber(value: value)) ?? String(format: "%.\(precision)f", value)
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
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .none
        return df.string(from: date)
    }

    static func dateTime(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df.string(from: date)
    }

    static func isoTimestamp(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: date)
    }
}
