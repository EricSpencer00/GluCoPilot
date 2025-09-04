import SwiftUI

// Shared UI styles: top gradient, gradient button style
extension LinearGradient {
    static func topBarColors() -> [Color] {
        // Try named assets first, fall back to system colors
        let start = UIColor(named: "TopGradientStart") ?? UIColor.systemBlue
        let end = UIColor(named: "TopGradientEnd") ?? UIColor.systemPurple
        return [Color(start), Color(end)]
    }

    static let topBar = LinearGradient(
        colors: topBarColors(),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct GradientButtonStyle: ButtonStyle {
    var colors: [Color] = [Color.accentColor, Color.accentColor.opacity(0.8)]
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    .opacity(configuration.isPressed ? 0.9 : 1.0)
            )
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .shadow(color: Color.black.opacity(configuration.isPressed ? 0.06 : 0.12), radius: configuration.isPressed ? 2 : 6, x: 0, y: configuration.isPressed ? 1 : 4)
            .scaleEffect(configuration.isPressed ? 0.995 : 1.0)
    }
}

struct TopGradientModifier: ViewModifier {
    func body(content: Content) -> some View {
        ZStack(alignment: .top) {
            LinearGradient(colors: LinearGradient.topBarColors(), startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea(edges: .top)
                .frame(height: 160)
                .blendMode(.overlay)
                .opacity(0.9)

            content
                .padding(.top, 8)
        }
    }
}

extension View {
    func withTopGradient() -> some View {
        self.modifier(TopGradientModifier())
    }
}
