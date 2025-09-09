import SwiftUI

struct ConsentView: View {
    let onAccept: () -> Void
    let onDecline: () -> Void
    @State private var hasAcceptedPrivacyPolicy = false
    @State private var hasAcceptedTerms = false
    @State private var showPrivacyPolicy = false
    @State private var showTerms = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Your Privacy Matters")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .padding(.bottom, 10)
                
                Text("Before you start using GluCoPilot, we need your consent to collect and process your health data to provide you with personalized insights and recommendations.")
                    .font(.body)
                
                VStack(alignment: .leading, spacing: 15) {
                    Text("Data We Collect")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        dataPointRow(icon: "drop.fill", text: "Blood glucose readings")
                        dataPointRow(icon: "heart.fill", text: "Heart rate")
                        dataPointRow(icon: "flame.fill", text: "Activity and exercise data")
                        dataPointRow(icon: "bed.double.fill", text: "Sleep data")
                        dataPointRow(icon: "fork.knife", text: "Nutritional information")
                    }
                    .padding(.leading)
                }
                .padding(.vertical, 10)
                
                Text("GluCoPilot uses this data to:")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 10) {
                    dataPointRow(icon: "brain.head.profile", text: "Generate AI-powered insights about your health patterns")
                    dataPointRow(icon: "chart.line.uptrend.xyaxis", text: "Track and visualize your glucose trends")
                    dataPointRow(icon: "lightbulb.fill", text: "Provide personalized recommendations")
                }
                .padding(.leading)
                .padding(.bottom, 10)
                
                Text("Your data security is our priority. We use industry-standard encryption and security measures to protect your information.")
                    .font(.body)
                    .padding(.vertical, 10)
                
                Text("Medical Disclaimer")
                    .font(.headline)
                
                Text("GluCoPilot is designed to provide general guidance for diabetes management and is not a replacement for professional medical advice. Always consult with your healthcare provider regarding your health conditions.")
                    .font(.body)
                    .padding(.bottom, 20)
                
                VStack(alignment: .leading, spacing: 15) {
                    Toggle(isOn: $hasAcceptedPrivacyPolicy) {
                        HStack {
                            Text("I have read and agree to the ")
                            Button("Privacy Policy") {
                                showPrivacyPolicy = true
                            }
                            .foregroundColor(.blue)
                        }
                    }
                    
                    Toggle(isOn: $hasAcceptedTerms) {
                        HStack {
                            Text("I have read and agree to the ")
                            Button("Terms of Service") {
                                showTerms = true
                            }
                            .foregroundColor(.blue)
                        }
                    }
                }
                .padding(.vertical, 10)
                
                HStack {
                    Button(action: {
                        onDecline()
                    }) {
                        Text("Decline")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(10)
                    }
                    
                    Button(action: {
                        onAccept()
                    }) {
                        Text("Accept & Continue")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(hasAcceptedPrivacyPolicy && hasAcceptedTerms ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(!hasAcceptedPrivacyPolicy || !hasAcceptedTerms)
                }
                .padding(.top, 20)
            }
            .padding()
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            NavigationView {
                StaticDocumentView(title: "Privacy Policy", content: StaticDocumentView.privacyPlaceholder)
                    .navigationBarItems(trailing: Button("Done") {
                        showPrivacyPolicy = false
                    })
            }
        }
        .sheet(isPresented: $showTerms) {
            NavigationView {
                StaticDocumentView(title: "Terms of Service", content: StaticDocumentView.termsPlaceholder)
                    .navigationBarItems(trailing: Button("Done") {
                        showTerms = false
                    })
            }
        }
        .withTopGradient()
    }
    
    private func dataPointRow(icon: String, text: String) -> some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            Text(text)
                .font(.body)
            Spacer()
        }
    }
}

struct ConsentView_Previews: PreviewProvider {
    static var previews: some View {
        ConsentView(onAccept: {}, onDecline: {})
    }
}
