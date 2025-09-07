import SwiftUI

struct StaticDocumentView: View {
    let title: String
    let content: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(title)
                    .font(.title)
                    .fontWeight(.bold)

                Text(content)
                    .font(.body)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
            }
            .padding()
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .withTopGradient()
    }
}

extension StaticDocumentView {
    static let privacyPlaceholder = "\nGluCoPilot Privacy Policy\n\nThis is a placeholder privacy policy. Replace with your app's full privacy policy text.\n\n• What data we collect\n• How we use it\n• How users can request deletion or export of their data\n\n" 

    static let termsPlaceholder = "\nTerms of Service\n\nThis is a placeholder Terms of Service. Replace with your full terms.\n\n• User responsibilities\n• Limitations of liability\n• Governing law\n\n"

    static let helpPlaceholder = "\nHelp & Support\n\nIf you need assistance with GluCoPilot, check the FAQ and troubleshooting steps below, or contact support.\n\n- FAQ\n- Troubleshooting\n\n"

    static let contactPlaceholder = "\nContact Us\n\nEmail: support@yourdomain.example\nPhone: (optional)\n\nWe aim to respond within 48 hours.\n"
}
