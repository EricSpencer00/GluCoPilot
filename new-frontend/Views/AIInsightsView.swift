import SwiftUI

struct AIInsightsView: View {
    @EnvironmentObject var apiManager: APIManager
    @EnvironmentObject var dexcomManager: DexcomManager
    @State private var insights: [AIInsight] = []
    @State private var isLoading = false
    @State private var lastUpdateDate: Date?
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 16) {
                    Image(systemName: "brain.head.profile.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.purple.gradient)
                    
                    Text("AI Insights")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Personalized recommendations based on your glucose, activity, and health data")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Refresh Button
                Button(action: refreshInsights) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        
                        Text(isLoading ? "Generating Insights..." : "Refresh Insights")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.purple.gradient)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(isLoading)
                .padding(.horizontal)
                
                // Last Update Info
                if let lastUpdate = lastUpdateDate {
                    Text("Last updated: \(lastUpdate.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                // Insights List
                LazyVStack(spacing: 16) {
                    ForEach(insights) { insight in
                        InsightCard(insight: insight)
                    }
                }
                .padding(.horizontal)
                
                // Empty State
                if insights.isEmpty && !isLoading {
                    VStack(spacing: 16) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.gray)
                        
                        Text("No insights yet")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        Text("Tap 'Refresh Insights' to generate AI-powered recommendations based on your data")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.vertical, 40)
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("AI Insights")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await refreshInsightsAsync()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            if insights.isEmpty {
                refreshInsights()
            }
        }
    }
    
    private func refreshInsights() {
        isLoading = true
        
        Task {
            await refreshInsightsAsync()
        }
    }
    
    private func refreshInsightsAsync() async {
        do {
            let newInsights = try await apiManager.generateInsights()
            
            await MainActor.run {
                isLoading = false
                insights = newInsights
                lastUpdateDate = Date()
            }
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

struct InsightCard: View {
    let insight: AIInsight
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: insight.icon)
                    .font(.title3)
                    .foregroundStyle(insight.priorityColor)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(insight.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text(insight.category)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                }
                
                Spacer()
                
                Text(insight.priority.rawValue)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(insight.priorityColor.opacity(0.2))
                    .foregroundStyle(insight.priorityColor)
                    .clipShape(Capsule())
            }
            
            // Description
            Text(insight.description)
                .font(.body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            
            // Action Items
            if !insight.actionItems.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recommended Actions:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    ForEach(insight.actionItems, id: \.self) { action in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle")
                                .font(.caption)
                                .foregroundStyle(.blue)
                                .padding(.top, 2)
                            
                            Text(action)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                        }
                    }
                }
            }
            
            // Timestamp
            HStack {
                Spacer()
                Text("Generated \(insight.timestamp.formatted(.relative(presentation: .named)))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
}

struct AIInsight: Identifiable, Codable {
    let id = UUID()
    let title: String
    let description: String
    let category: String
    let priority: Priority
    let actionItems: [String]
    let timestamp: Date
    
    enum Priority: String, Codable, CaseIterable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
    }
    
    var icon: String {
        switch category.lowercased() {
        case "glucose": return "drop.fill"
        case "activity": return "figure.walk"
        case "nutrition": return "fork.knife"
        case "sleep": return "bed.double.fill"
        case "general": return "lightbulb.fill"
        default: return "info.circle.fill"
        }
    }
    
    var priorityColor: Color {
        switch priority {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }
}

#Preview {
    NavigationStack {
        AIInsightsView()
            .environmentObject(APIManager())
            .environmentObject(DexcomManager())
    }
}
