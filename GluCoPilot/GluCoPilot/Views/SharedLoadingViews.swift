import SwiftUI

struct Shimmer: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        LinearGradient(gradient: Gradient(colors: [Color.gray.opacity(0.25), Color.gray.opacity(0.12), Color.gray.opacity(0.25)]), startPoint: .leading, endPoint: .trailing)
            .rotationEffect(.degrees(20))
            .mask(
                Rectangle()
                    .fill(Color.white)
                    .rotationEffect(.degrees(Double(phase * 360)))
            )
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

struct SkeletonCard: View {
    var height: CGFloat = 20
    var cornerRadius: CGFloat = 8

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(LinearGradient.cardGradient(base: Color.gray))
            .frame(height: height)
            .overlay(Shimmer().blendMode(.overlay))
    }
}

struct LoadingStack: View {
    var count: Int = 3

    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<count, id: \.self) { _ in
                SkeletonCard(height: 18, cornerRadius: 10)
            }
        }
    .padding()
    .cardStyle(baseColor: Color.gray, cornerRadius: 12)
    }
}
