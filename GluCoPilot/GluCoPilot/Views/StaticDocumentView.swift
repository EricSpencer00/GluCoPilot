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
    static let privacyPlaceholder = """
    GluCoPilot Privacy Policy

    This is a placeholder privacy policy. Replace with your app's full privacy policy text.

    • What data we collect
    • How we use it
    • How users can request deletion or export of their data

    We use Hugging Face's open-source AI models (OSS 20B and OSS 120B) to generate insights. All health data used with these models is anonymized and never stored in any database owned by the developer.

    All data transformation is stateless, meaning data is processed transiently for each request and is not persisted by the app outside of HealthKit-managed storage.

    Keep in mind the accuracy of AI: do not fully trust any information given by the AI. This app is intended to provide general guidance for diabetes care and is not a replacement for an endocrinologist or medical professional.

    """

    static let termsPlaceholder = "\nTerms of Service\n\nThis is a placeholder Terms of Service. Replace with your full terms.\n\n• User responsibilities\n• Limitations of liability\n• Governing law\n\n"

    static let helpPlaceholder = "\nHelp & Support\n\nIf you need assistance with GluCoPilot, check the FAQ and troubleshooting steps below, or contact support.\n\n- FAQ\n- Troubleshooting\n\n"

    static let contactPlaceholder = "\nContact Us\n\nEmail: support@yourdomain.example\nPhone: (optional)\n\nWe aim to respond within 48 hours.\n"
}
