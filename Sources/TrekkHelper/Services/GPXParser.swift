import Foundation

enum GPXParserError: Error {
    case invalidData
    case parseFailed
}

struct GPXParser {
    static func parse(url: URL) throws -> Track {
        let data = try Data(contentsOf: url)
        let parser = XMLParser(data: data)
        let delegate = GPXParserDelegate()
        parser.delegate = delegate
        guard parser.parse(), !delegate.points.isEmpty else {
            throw GPXParserError.parseFailed
        }

        return Track(name: url.deletingPathExtension().lastPathComponent, points: delegate.points)
    }
}

private class GPXParserDelegate: NSObject, XMLParserDelegate {
    var points: [TrackPoint] = []
    private var currentElement = ""
    private var currentLatitude: Double?
    private var currentLongitude: Double?
    private var currentElevation: Double?
    private var currentTimestamp: Date?
    private var currentText = ""

    private let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName.lowercased()
        currentText = ""

        if currentElement == "trkpt" || currentElement == "wpt" || currentElement == "rtept" {
            currentLatitude = Double(attributeDict["lat"] ?? "")
            currentLongitude = Double(attributeDict["lon"] ?? "")
            currentElevation = nil
            currentTimestamp = nil
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let element = elementName.lowercased()
        switch element {
        case "ele":
            currentElevation = Double(currentText.trimmingCharacters(in: .whitespacesAndNewlines))
        case "time":
            currentTimestamp = dateFormatter.date(from: currentText.trimmingCharacters(in: .whitespacesAndNewlines))
        case "trkpt", "wpt", "rtept":
            if let lat = currentLatitude, let lon = currentLongitude {
                let point = TrackPoint(latitude: lat, longitude: lon, elevation: currentElevation, timestamp: currentTimestamp)
                points.append(point)
            }
            currentLatitude = nil
            currentLongitude = nil
            currentElevation = nil
            currentTimestamp = nil
        default:
            break
        }
    }
}
