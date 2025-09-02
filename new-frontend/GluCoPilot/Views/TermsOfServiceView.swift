import SwiftUI

struct TermsOfServiceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Terms of Service")
                    .font(.largeTitle)
                    .bold()
                Text("These are the terms of service. Nonsense content goes here. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nulla facilisi. Suspendisse potenti.")
            }
            .padding()
        }
    }
}

#Preview {
    TermsOfServiceView()
}
