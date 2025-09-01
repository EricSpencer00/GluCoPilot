import SwiftUI

struct AIInsightsView: View {
    // Note: These should be proper manager types when module resolution is complete
    @State private var apiManager: Any? = nil
    @State private var dexcomManager: Any? = nil
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
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
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
        // For now, create mock insights until API integration is complete
        let mockInsights = [
                AIInsight(
                    title: "Blood Sugar Trend",
                    description: "Your blood sugar has been trending upward over the past 3 days.",
                    type: .bloodSugar,
                    priority: .medium,
                    timestamp: Date(),
                    actionItems: ["Monitor carbohydrate intake", "Check medication timing"],
                    dataPoints: ["average": 140.5, "change": 15.2]
                ),
                AIInsight(
                    title: "Exercise Impact",
                    description: "Regular exercise is helping stabilize your glucose levels.",
                    type: .exercise,
                    priority: .low,
                    timestamp: Date(),
                    actionItems: ["Continue current exercise routine"],
                    dataPoints: ["correlation": 0.8, "improvement": 12.3]
                )
            ]
            
            await MainActor.run {
                isLoading = false
                insights = mockInsights
                lastUpdateDate = Date()
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

#Preview {
    NavigationStack {
        AIInsightsView()
    }
}
