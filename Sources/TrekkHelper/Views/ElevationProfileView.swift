import SwiftUI

struct ElevationProfileView: View {
    let points: [TrackPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("海拔剖面")
                .font(.headline)
            GeometryReader { proxy in
                Canvas { context, size in
                    let line = profilePath(in: size)
                    context.stroke(line, with: .color(.blue), lineWidth: 2)

                    if let fill = fillPath(in: size) {
                        context.fill(fill, with: .linearGradient(
                            Gradient(colors: [.blue.opacity(0.2), .clear]),
                            startPoint: .top,
                            endPoint: .bottom
                        ))
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func profilePath(in size: CGSize) -> Path {
        var path = Path()
        let elevations = points.compactMap(\.elevation)
        guard !elevations.isEmpty else { return path }

        let minElevation = elevations.min() ?? 0
        let maxElevation = elevations.max() ?? 0
        let elevationRange = max(maxElevation - minElevation, 1)
        let step = size.width / CGFloat(max(elevations.count - 1, 1))

        for (index, elev) in elevations.enumerated() {
            let x = CGFloat(index) * step
            let y = size.height - CGFloat((elev - minElevation) / elevationRange) * size.height
            let point = CGPoint(x: x, y: y)
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        return path
    }

    private func fillPath(in size: CGSize) -> Path? {
        var path = profilePath(in: size)
        guard !points.isEmpty else { return nil }
        path.addLine(to: CGPoint(x: size.width, y: size.height))
        path.addLine(to: CGPoint(x: 0, y: size.height))
        path.closeSubpath()
        return path
    }
}
