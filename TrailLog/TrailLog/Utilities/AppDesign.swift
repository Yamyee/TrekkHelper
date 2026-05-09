import SwiftUI
import UIKit

enum AppDesign {
    static let background = Color(red: 0.98, green: 0.96, blue: 0.93)
    static let backgroundAccent = Color(red: 0.95, green: 0.91, blue: 0.86)
    static let surface = Color(red: 0.995, green: 0.987, blue: 0.975)
    static let elevatedSurface = Color(red: 0.96, green: 0.93, blue: 0.90)
    static let panel = Color(red: 0.93, green: 0.88, blue: 0.83)
    static let ink = Color(red: 0.17, green: 0.13, blue: 0.11)
    static let secondaryInk = Color(red: 0.45, green: 0.37, blue: 0.33)
    static let accent = Color(red: 0.84, green: 0.47, blue: 0.29)
    static let accentDeep = Color(red: 0.66, green: 0.34, blue: 0.20)
    static let line = Color.black.opacity(0.07)
    static let success = Color(red: 0.46, green: 0.56, blue: 0.35)
    static let warning = Color(red: 0.84, green: 0.62, blue: 0.30)
    static let error = Color(red: 0.74, green: 0.31, blue: 0.28)
    static let shadow = Color.black.opacity(0.08)

    static let cardRadius: CGFloat = 24
    static let pillRadius: CGFloat = 18
    static let horizontalPadding: CGFloat = 20
}

extension Font {
    static let appHero = Font.system(size: 34, weight: .semibold, design: .serif)
    static let appTitle = Font.system(size: 24, weight: .semibold, design: .serif)
    static let appSection = Font.system(size: 18, weight: .semibold, design: .rounded)
    static let appBody = Font.system(size: 16, weight: .regular, design: .rounded)
    static let appCaption = Font.system(size: 12, weight: .medium, design: .rounded)
}

struct AppCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppDesign.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppDesign.cardRadius, style: .continuous)
                    .stroke(AppDesign.line, lineWidth: 1)
            )
            .shadow(color: AppDesign.shadow, radius: 16, x: 0, y: 8)
    }
}

extension View {
    func appCardStyle() -> some View {
        modifier(AppCardModifier())
    }

    func appPanelBackground() -> some View {
        background(
            LinearGradient(
                colors: [AppDesign.background, AppDesign.backgroundAccent],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }
}

struct AppPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.appBody.weight(.semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .background(
                AppDesign.accent
            )
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.pillRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppDesign.pillRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
    }
}

struct AppStatusPill: View {
    let text: String
    let tint: Color

    var body: some View {
        Text(text)
            .font(.appCaption)
            .foregroundColor(tint)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppDesign.panel)
            .overlay(
                Capsule()
                    .stroke(tint.opacity(0.28), lineWidth: 1)
            )
            .clipShape(Capsule())
    }
}

struct AppLoadingIndicator: UIViewRepresentable {
    func makeUIView(context: Context) -> UIActivityIndicatorView {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = UIColor(red: 0.66, green: 0.34, blue: 0.20, alpha: 1)
        indicator.startAnimating()
        return indicator
    }

    func updateUIView(_ uiView: UIActivityIndicatorView, context: Context) {
        uiView.startAnimating()
    }
}
