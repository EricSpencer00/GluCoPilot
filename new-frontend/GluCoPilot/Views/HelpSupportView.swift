import SwiftUI

struct HelpSupportView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Help & Support")
                    .font(.largeTitle)
                    .bold()
                Text("This is the help and support page. Nonsense content goes here. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nulla facilisi. Suspendisse potenti.")
            }
            .padding()
        }
    }
}

#Preview {
    HelpSupportView()
}
