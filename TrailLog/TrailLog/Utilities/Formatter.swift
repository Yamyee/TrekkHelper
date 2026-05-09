import Foundation

enum Formatter {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy.MM.dd HH:mm"
        return formatter
    }()

    static func distance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.2f km", meters / 1000)
        }
        return String(format: "%.0f m", meters)
    }

    static func meters(_ value: Double) -> String {
        String(format: "%.0f m", value)
    }

    static func dateTime(_ date: Date) -> String {
        dateFormatter.string(from: date)
    }

    static func durationHours(_ hours: Double) -> String {
        let totalMinutes = Int((hours * 60).rounded())
        let hourPart = totalMinutes / 60
        let minutePart = totalMinutes % 60
        if minutePart == 0 {
            return "\(hourPart)h"
        }
        return "\(hourPart)h \(minutePart)m"
    }
}
