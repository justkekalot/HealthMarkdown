import Foundation
import CoreLocation

/// Builds a standard GPX 1.1 document from workout GPS routes — one <trk> per
/// workout, so the file opens in Strava, Garmin, Gaia, Apple/Google Maps, etc.
enum WorkoutGPX {
    static let header = """
    <?xml version="1.0" encoding="UTF-8"?>
    <gpx version="1.1" creator="HealthMarkdown" xmlns="http://www.topografix.com/GPX/1/1">

    """
    static let footer = "</gpx>\n"

    /// One <trk> for a single workout. Coordinates use a forced '.' decimal.
    static func track(for w: WorkoutDetail, points: [CLLocation]) -> String {
        guard !points.isEmpty else { return "" }
        var s = "  <trk>\n    <name>\(escape(w.activityName)) — \(Fmt.isoTimestamp(w.start))</name>\n    <trkseg>\n"
        for p in points {
            s += "      <trkpt lat=\"\(coord(p.coordinate.latitude))\" lon=\"\(coord(p.coordinate.longitude))\">\n"
            if p.verticalAccuracy >= 0 { s += "        <ele>\(String(format: "%.1f", p.altitude))</ele>\n" }
            s += "        <time>\(Fmt.isoTimestamp(p.timestamp))</time>\n"
            s += "      </trkpt>\n"
        }
        return s + "    </trkseg>\n  </trk>\n"
    }

    private static func coord(_ v: CLLocationDegrees) -> String { String(format: "%.6f", v) }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
}
