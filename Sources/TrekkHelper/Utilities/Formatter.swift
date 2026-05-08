import Foundation

enum Formatter {
    static func distance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.2f km", meters / 1000)
        }
        return String(format: "%.0f m", meters)
    }

    static func meters(_ value: Double) -> String {
        String(format: "%.0f m", value)
    }
}
