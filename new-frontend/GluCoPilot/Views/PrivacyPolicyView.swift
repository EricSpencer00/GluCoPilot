import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Privacy Policy")
                    .font(.largeTitle)
                    .bold()
                Text("This is the privacy policy. Nonsense content goes here. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nulla facilisi. Suspendisse potenti.")
            }
            .padding()
        }
    }
}

#Preview {
    PrivacyPolicyView()
}
