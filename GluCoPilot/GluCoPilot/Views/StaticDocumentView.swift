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
    # GluCoPilot Privacy Policy

    ## Introduction
    GluCoPilot ("we," "our," or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our mobile application GluCoPilot (the "App").
    
    Please read this Privacy Policy carefully. By using the App, you consent to the collection and use of information in accordance with this policy.

    ## Information We Collect
    
    ### Health and Fitness Data
    With your explicit permission, we collect health data from Apple HealthKit, including:
    - Blood glucose readings
    - Step count
    - Heart rate
    - Sleep data
    - Exercise/workout information
    - Nutritional data
    
    ### Personal Information
    - Name and email address (from Apple Sign In)
    - User preferences and app settings
    
    ## How We Use Your Information
    
    - To provide personalized insights about your glucose levels and health patterns
    - To analyze trends in your health data
    - To improve our algorithms and app functionality
    - To sync your data between devices
    
    ## Data Storage and Security
    
    Your health data is stored securely using industry-standard encryption. We implement appropriate technical and organizational measures to protect your personal information against unauthorized access, alteration, disclosure, or destruction.
    
    ## Third-Party Services
    
    We use the following third-party services:
    - Apple HealthKit
    - Apple Sign In
    
    We do not share your HealthKit data with third parties for marketing, advertising, or other commercial purposes.
    
    ## AI Model Usage
    
    We use Hugging Face's open-source AI models (OSS 20B and OSS 120B) to generate insights. All health data used with these models is anonymized and never stored in any database owned by the developer.

    All data transformation is stateless, meaning data is processed transiently for each request and is not persisted by the app outside of HealthKit-managed storage.
    
    ## Medical Disclaimer
    
    Keep in mind the accuracy of AI: do not fully trust any information given by the AI. This app is intended to provide general guidance for diabetes care and is not a replacement for an endocrinologist or medical professional.
    
    ## Your Rights
    
    You have the right to:
    - Access the personal information we have about you
    - Request correction of inaccurate data
    - Request deletion of your data
    - Withdraw consent at any time
    
    ## Changes to This Privacy Policy
    
    We may update our Privacy Policy from time to time. We will notify you of any changes by posting the new Privacy Policy on this page and updating the "Last Updated" date.
    
    ## Contact Us
    
    If you have any questions about this Privacy Policy, please contact us at: [YOUR CONTACT EMAIL]
    
    Last Updated: September 8, 2025
    """

    static let termsPlaceholder = """
    # Terms of Service

    ## Acceptance of Terms
    
    By downloading, installing, or using GluCoPilot ("the App"), you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use the App.
    
    ## App Usage
    
    ### License
    
    We grant you a limited, non-exclusive, non-transferable, revocable license to use the App for your personal, non-commercial purposes.
    
    ### User Responsibilities
    
    You agree to:
    - Provide accurate information when using the App
    - Keep your account information secure
    - Use the App in compliance with all applicable laws and regulations
    - Not attempt to reverse engineer, modify, or create derivative works of the App
    
    ## Medical Disclaimer
    
    The App is not a substitute for professional medical advice, diagnosis, or treatment. Always seek the advice of your physician or other qualified health provider with any questions you may have regarding a medical condition.
    
    The App uses artificial intelligence to generate insights and recommendations. These insights are provided for informational purposes only and may not be accurate or applicable to your specific health situation.
    
    ## Data and Privacy
    
    Your use of the App is also governed by our Privacy Policy, which is incorporated into these Terms by reference.
    
    ## Limitation of Liability
    
    To the maximum extent permitted by law, we shall not be liable for any indirect, incidental, special, consequential, or punitive damages, or any loss of profits or revenues, whether incurred directly or indirectly, or any loss of data, use, goodwill, or other intangible losses resulting from:
    
    - Your use or inability to use the App
    - Any unauthorized access to or use of our servers and/or any personal information stored therein
    - Any errors or inaccuracies in the content or data provided by the App
    
    ## Indemnification
    
    You agree to defend, indemnify, and hold us harmless from and against any claims, liabilities, damages, losses, and expenses, including reasonable attorneys' fees and costs, arising out of or in any way connected with your access to or use of the App.
    
    ## Changes to Terms
    
    We reserve the right to modify these Terms at any time. We will provide notice of any material changes by updating the "Last Updated" date at the bottom of these Terms. Your continued use of the App after such modifications will constitute your acknowledgment and agreement to the modified Terms.
    
    ## Governing Law
    
    These Terms shall be governed by and construed in accordance with the laws of [YOUR JURISDICTION], without regard to its conflict of law provisions.
    
    ## Contact Us
    
    If you have any questions about these Terms, please contact us at: [YOUR CONTACT EMAIL]
    
    Last Updated: September 8, 2025
    """

    static let helpPlaceholder = """
    # Help & Support
    
    ## Frequently Asked Questions
    
    ### How does GluCoPilot access my health data?
    GluCoPilot uses Apple HealthKit to securely access health data from your device. We only access data that you've explicitly granted permission for.
    
    ### How accurate are the AI insights?
    While our AI models are trained on extensive datasets, the insights are provided for informational purposes only and should not replace medical advice from healthcare professionals.
    
    ### Is my data shared with third parties?
    No. Your health data is processed locally and anonymized before being used with our AI models. We do not share your HealthKit data with third parties for marketing or advertising purposes.
    
    ### How do I delete my data?
    You can delete your account and all associated data from the Settings tab. Additionally, you can revoke HealthKit permissions at any time through your device's Settings app.
    
    ## Troubleshooting
    
    ### App not showing latest glucose readings
    - Ensure HealthKit permissions are enabled
    - Check that your glucose monitoring device is properly synced with Apple Health
    - Try pulling down on the main screen to refresh data
    - Restart the app
    
    ### Authentication issues
    - Ensure you're signed in with Apple ID
    - Check your internet connection
    - Try signing out and signing back in
    
    ### App crashes or performance issues
    - Make sure your iOS is updated to the latest version
    - Close other apps running in the background
    - Restart your device
    - Reinstall the app if problems persist
    
    ## Contact Support
    
    If you're experiencing issues not covered above, please contact our support team at [YOUR SUPPORT EMAIL].
    
    We aim to respond to all inquiries within 48 hours.
    """

    static let contactPlaceholder = """
    # Contact Us
    
    We're here to help with any questions, feedback, or support needs you may have regarding GluCoPilot.
    
    ## Support Email
    [YOUR SUPPORT EMAIL]
    
    ## Business Inquiries
    [YOUR BUSINESS EMAIL]
    
    ## Mailing Address
    [YOUR PHYSICAL ADDRESS] (if applicable)
    
    ## Response Time
    We aim to respond to all inquiries within 48 hours during business days.
    
    ## Follow Us
    [YOUR SOCIAL MEDIA LINKS] (if applicable)
    
    ## Report an Issue
    If you've encountered a bug or technical issue, please include:
    - Your device model
    - iOS version
    - Description of the issue
    - Steps to reproduce (if applicable)
    - Screenshots (if applicable)
    
    ## Feature Requests
    We value your input! If you have ideas for new features or improvements, please let us know at [YOUR FEEDBACK EMAIL].
    """
}
