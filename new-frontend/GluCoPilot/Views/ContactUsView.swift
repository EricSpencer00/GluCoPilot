import SwiftUI

struct ContactUsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Contact Us")
                    .font(.largeTitle)
                    .bold()
                Text("This is the contact us page. Nonsense content goes here. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nulla facilisi. Suspendisse potenti.")
            }
            .padding()
        }
    }
}

#Preview {
    ContactUsView()
}
