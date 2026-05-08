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
}
