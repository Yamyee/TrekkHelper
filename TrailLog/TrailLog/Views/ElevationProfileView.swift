import SwiftUI

struct ElevationProfileView: View {
    let points: [TrackPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("海拔剖面")
                .font(.appSection)
                .foregroundColor(AppDesign.ink)
            ZStack {
                AppDesign.elevatedSurface

                ElevationShape(points: points)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [AppDesign.accent.opacity(0.26), Color.clear]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                ElevationShape(points: points)
                    .stroke(AppDesign.accentDeep, lineWidth: 2.5)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 170)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
        .padding(22)
        .appCardStyle()
    }
}

struct ElevationShape: Shape {
    let points: [TrackPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let elevations = points.compactMap(\.elevation)
        guard !elevations.isEmpty else { return path }

        let minElevation = elevations.min() ?? 0
        let maxElevation = elevations.max() ?? 0
        let elevationRange = max(maxElevation - minElevation, 1)
        let step = rect.width / CGFloat(max(elevations.count - 1, 1))

        for (index, elev) in elevations.enumerated() {
            let x = rect.minX + CGFloat(index) * step
            let normalized = CGFloat((elev - minElevation) / elevationRange)
            let y = rect.maxY - normalized * rect.height
            let point = CGPoint(x: x, y: y)
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        // Close the path for fill
        if !elevations.isEmpty {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }

        return path
    }
}
