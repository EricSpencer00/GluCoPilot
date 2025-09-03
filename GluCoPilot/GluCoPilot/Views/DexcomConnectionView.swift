import SwiftUI

struct DexcomConnectionView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "xmark.octagon.fill")
                .font(.system(size: 64))
                .foregroundColor(.red)

            Text("Dexcom Integration Removed")
                .font(.title2)
                .fontWeight(.bold)

            Text("Dexcom integration has been removed from GluCoPilot. Please connect Apple Health (HealthKit) or a supported CGM source to sync glucose data.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding()

            Spacer()
        }
        .padding()
        .navigationTitle("Dexcom (Legacy)")
    }
}

#Preview {
    NavigationStack {
        DexcomConnectionView()

    }
}
