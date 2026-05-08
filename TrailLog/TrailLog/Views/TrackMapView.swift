import SwiftUI
import MapKit

struct TrackMapView: UIViewRepresentable {
    let segments: [[TrackPoint]]
    var isInteractive: Bool = false
    var maxRenderPointCount: Int = 300

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.pointOfInterestFilter = .excludingAll
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.isZoomEnabled = isInteractive
        mapView.isScrollEnabled = isInteractive
        mapView.isUserInteractionEnabled = isInteractive
        mapView.mapType = .mutedStandard
        mapView.backgroundColor = UIColor.systemGray6
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.isZoomEnabled = isInteractive
        mapView.isScrollEnabled = isInteractive
        mapView.isUserInteractionEnabled = isInteractive

        let coordinates = segments
            .map { simplifiedCoordinates(from: $0.map(\.coordinate), maxCount: maxRenderPointCount) }
            .filter { !$0.isEmpty }
        context.coordinator.updateMap(mapView, coordinateSegments: coordinates)
    }

    private func simplifiedCoordinates(from coordinates: [CLLocationCoordinate2D], maxCount: Int) -> [CLLocationCoordinate2D] {
        guard coordinates.count > maxCount, maxCount > 2 else { return coordinates }

        let strideLength = max(1, (coordinates.count - 2) / (maxCount - 2))
        var simplified = [coordinates[0]]

        var index = strideLength
        while index < coordinates.count - 1 {
            simplified.append(coordinates[index])
            index += strideLength
        }

        if simplified.last?.latitude != coordinates.last?.latitude || simplified.last?.longitude != coordinates.last?.longitude {
            simplified.append(coordinates[coordinates.count - 1])
        }

        return simplified
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        private let polylineTitle = "track-line"
        private let startTitle = "start-point"
        private let endTitle = "end-point"
        private var lastSignature: String?

        func updateMap(_ mapView: MKMapView, coordinateSegments: [[CLLocationCoordinate2D]]) {
            let signature = coordinatesSignature(for: coordinateSegments)
            guard signature != lastSignature else { return }
            lastSignature = signature

            mapView.removeOverlays(mapView.overlays)
            mapView.removeAnnotations(mapView.annotations)

            let flattenedCoordinates = coordinateSegments.flatMap { $0 }
            guard !flattenedCoordinates.isEmpty else { return }

            let polylines = coordinateSegments.map { coordinates in
                let polyline = MKPolyline(coordinates: coordinates, count: coordinates.count)
                polyline.title = polylineTitle
                return polyline
            }
            mapView.addOverlays(polylines)

            if let first = flattenedCoordinates.first {
                let annotation = MKPointAnnotation()
                annotation.coordinate = first
                annotation.title = startTitle
                mapView.addAnnotation(annotation)
            }

            if flattenedCoordinates.count > 1, let last = flattenedCoordinates.last {
                let annotation = MKPointAnnotation()
                annotation.coordinate = last
                annotation.title = endTitle
                mapView.addAnnotation(annotation)
            }

            let rect = polylines
                .map(\.boundingMapRect)
                .reduce(MKMapRect.null) { partialResult, rect in
                    partialResult.isNull ? rect : partialResult.union(rect)
                }
            let inset = UIEdgeInsets(top: 36, left: 24, bottom: 36, right: 24)
            mapView.setVisibleMapRect(rect, edgePadding: inset, animated: false)
        }

        private func coordinatesSignature(for coordinateSegments: [[CLLocationCoordinate2D]]) -> String {
            let flattenedCoordinates = coordinateSegments.flatMap { $0 }
            guard let first = flattenedCoordinates.first, let last = flattenedCoordinates.last else { return "empty" }
            return "\(coordinateSegments.count)-\(flattenedCoordinates.count)-\(first.latitude)-\(first.longitude)-\(last.latitude)-\(last.longitude)"
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let polyline = overlay as? MKPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }

            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = UIColor.systemBlue
            renderer.lineWidth = 4
            renderer.lineJoin = .round
            renderer.lineCap = .round
            return renderer
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let title = annotation.title ?? nil else { return nil }

            let identifier = "track-marker-\(title)"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.annotation = annotation
            view.canShowCallout = false
            view.animatesWhenAdded = false

            switch title {
            case startTitle:
                view.markerTintColor = .systemGreen
                view.glyphImage = UIImage(systemName: "flag.fill")
            case endTitle:
                view.markerTintColor = .systemRed
                view.glyphImage = UIImage(systemName: "flag.checkered")
            default:
                view.markerTintColor = .systemBlue
                view.glyphImage = UIImage(systemName: "mappin")
            }

            return view
        }
    }
}
