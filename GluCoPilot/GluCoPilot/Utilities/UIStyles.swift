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

        // Card-style gradient used across the app for subtle colorful backgrounds
        static func cardGradient(base: Color) -> LinearGradient {
            // Create a soft layered gradient biased toward the base color
            let c1 = base.opacity(0.18)
            let c2 = base.opacity(0.06)
            let c3 = Color(.systemBackground).opacity(0.02)
            return LinearGradient(colors: [c1, c2, c3], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
}

    // Convenience modifier that applies the app card gradient with a subtle shadow
    struct CardBackgroundModifier: ViewModifier {
        var baseColor: Color = .accentColor
        var cornerRadius: CGFloat = 16

        func body(content: Content) -> some View {
            content
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(LinearGradient.cardGradient(base: baseColor))
                        .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 4)
                )
        }
    }

    extension View {
        func cardStyle(baseColor: Color = .accentColor, cornerRadius: CGFloat = 16) -> some View {
            self.modifier(CardBackgroundModifier(baseColor: baseColor, cornerRadius: cornerRadius))
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

// A global top gradient that fills the top 20% of the screen with the app's
// primary gradient and the remainder with the system background (white/black
// depending on color scheme). Use this on the app root so all screens inherit
// the same visual treatment.
struct GlobalTopGradientModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    LinearGradient(colors: LinearGradient.topBarColors(), startPoint: .topLeading, endPoint: .bottomTrailing)
                        .frame(height: max(120, geo.size.height * 0.20))
                        .ignoresSafeArea(edges: .top)

                    // Fill the rest with system background so content cards read well
                    (colorScheme == .dark ? Color.black : Color.white)
                        .frame(height: geo.size.height - max(120, geo.size.height * 0.20))
                }

                content
            }
        }
    }
}

extension View {
    func withGlobalTopGradient() -> some View {
        self.modifier(GlobalTopGradientModifier())
    }
}
