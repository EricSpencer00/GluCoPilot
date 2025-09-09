import SwiftUI

struct MedicalDisclaimerView: View {
    let onAccept: () -> Void
    @State private var hasAcknowledged = false
    
    var body: some View {
        ZStack {
            // Solid background to prevent text from showing over tab bar
            Color(.systemBackground)
                .edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header with fixed white color
                    Text("Medical Disclaimer")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.bottom, 10)
                    
                    Text("IMPORTANT: NOT A MEDICAL DEVICE")
                        .font(.headline)
                        .foregroundColor(.red)
                        .padding(.bottom, 5)
                    
                    Text("GluCoPilot is not a medical device and is not intended to diagnose, treat, cure, or prevent any disease or health condition. The information provided by this app is for informational and educational purposes only.")
                        .font(.body)
                    
                    Text("NOT A SUBSTITUTE FOR MEDICAL ADVICE")
                        .font(.headline)
                        .foregroundColor(.red)
                        .padding(.vertical, 5)
                    
                    Text("The content provided by GluCoPilot, including AI-generated insights and recommendations, should not replace professional medical advice, diagnosis, or treatment. Always seek the advice of your physician or other qualified health provider with any questions you may have regarding a medical condition.")
                        .font(.body)
                    
                    Text("RELIANCE ON APP INFORMATION")
                        .font(.headline)
                        .foregroundColor(.red)
                        .padding(.vertical, 5)
                    
                    Text("Any reliance you place on information provided by GluCoPilot is strictly at your own risk. The app uses artificial intelligence to analyze health data, which may not always produce accurate or complete information. Always verify any information with healthcare professionals before making medical decisions.")
                        .font(.body)
                    
                    Text("ACCURACY OF DATA")
                        .font(.headline)
                        .foregroundColor(.red)
                        .padding(.vertical, 5)
                    
                    Text("While we strive to display accurate information, GluCoPilot relies on data from connected devices and services. We cannot guarantee the accuracy, completeness, or timeliness of this data. Always confirm readings with medically approved devices when making treatment decisions.")
                        .font(.body)
                    
                    Text("EMERGENCY SITUATIONS")
                        .font(.headline)
                        .foregroundColor(.red)
                        .padding(.vertical, 5)
                    
                    Text("In case of a medical emergency, contact emergency services immediately (call 911 in the US or your local emergency number). GluCoPilot is not designed to handle emergency situations and should not be relied upon in such circumstances.")
                        .font(.body)
                    
                    Toggle(isOn: $hasAcknowledged) {
                        Text("I acknowledge that GluCoPilot is not a medical device and should not replace professional medical advice")
                            .font(.subheadline)
                    }
                    .padding(.top, 20)
                    
                    Button(action: {
                        if hasAcknowledged {
                            onAccept()
                        }
                    }) {
                        Text("I Understand and Accept")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(hasAcknowledged ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(!hasAcknowledged)
                    .padding(.top, 20)
                    .padding(.bottom, 40)  // Add extra padding at bottom for scrolling
                }
                .padding()
            }
            .safeAreaInset(edge: .top) {
                // Empty view with padding to ensure content doesn't go under the status bar
                Color.clear.frame(height: 0)
            }
            .background(
                // Custom background for the entire view
                LinearGradient(
                    gradient: Gradient(colors: [Color.blue, Color(.systemBackground)]),
                    startPoint: .top,
                    endPoint: .center
                )
                .edgesIgnoringSafeArea(.all)
            )
        }
    }
    
    struct MedicalDisclaimerView_Previews: PreviewProvider {
        static var previews: some View {
            MedicalDisclaimerView(onAccept: {})
        }
    }
}
