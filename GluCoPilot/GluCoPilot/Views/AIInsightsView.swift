import SwiftUI
import Charts

struct AIInsightsView: View {
    @EnvironmentObject private var apiManager: APIManager
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @State private var insights: [AIInsight] = []
    @State private var isLoading = false
    @State private var lastUpdateDate: Date?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var selectedInsight: AIInsight?
    @State private var showDetailView = false
    @State private var userPrompt: String = ""
    
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
                
                // Prompt input (optional)
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ask a question or set a focus (optional)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("e.g., Help me improve my post-dinner glucose", text: $userPrompt)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.horizontal)
                
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
                }
                .buttonStyle(GradientButtonStyle(colors: [Color.purple, Color.blue]))
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
                            .onTapGesture {
                                selectedInsight = insight
                                showDetailView = true
                            }
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
        .sheet(isPresented: $showDetailView) {
            if let insight = selectedInsight {
                InsightDetailView(insight: insight)
            }
        }
        .onAppear {
            if insights.isEmpty {
                refreshInsights()
            }
        }
        .withTopGradient()
    }
    
    private func refreshInsights() {
        isLoading = true
        
        Task {
            await refreshInsightsAsync()
        }
    }
    
    private func refreshInsightsAsync() async {
        do {
            // Package last 24h HealthKit data for stateless insights
            let hk = try await healthKitManager.fetchLast24HoursData()
            let apiHealth = APIManagerHealthData(
                glucose: hk.glucose.map { g in
                    APIManagerGlucoseReading(value: Int(g.value), trend: "", timestamp: g.timestamp, unit: g.unit)
                },
                workouts: hk.workouts.map { w in
                    APIManagerWorkoutData(type: w.name, duration: w.duration, calories: w.calories, startDate: w.startDate, endDate: w.endDate)
                },
                nutrition: hk.nutrition.map { n in
                    APIManagerNutritionData(name: n.name, calories: n.calories, carbs: n.carbs, protein: n.protein, fat: n.fat, timestamp: n.timestamp)
                },
                timestamp: Date()
            )
            
            // Include cached items from the last 24h
            let since = Calendar.current.date(byAdding: .hour, value: -24, to: Date())!
            let cached = CacheManager.shared.getItems(since: since)
            // Upload both HealthKit data and cached logs for richer insights
            let aiInsights = try await apiManager.uploadCacheAndGenerateInsights(healthData: apiHealth, cachedItems: cached)
            
            await MainActor.run {
                isLoading = false
                insights = aiInsights
                lastUpdateDate = Date()
            }
        } catch {
            print("Error fetching insights: \(error.localizedDescription)")
            
            await MainActor.run {
                isLoading = false
                errorMessage = "Failed to generate insights: \(error.localizedDescription)"
                showError = true
                
                // If there are no existing insights, create some defaults
                if insights.isEmpty {
                    insights = [
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
                }
            }
        }
    }
    
    
    struct InsightDetailView: View {
        let insight: AIInsight
        @State private var selectedTimeframe: Timeframe = .day
        
        enum Timeframe: String, CaseIterable {
            case day = "24h"
            case week = "7d"
            case month = "30d"
        }
        
        var body: some View {
            NavigationView {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header
                        HStack {
                            Image(systemName: insight.icon)
                                .font(.largeTitle)
                                .foregroundStyle(insight.priorityColor)
                            
                            VStack(alignment: .leading) {
                                Text(insight.title)
                                    .font(.title)
                                    .fontWeight(.bold)
                                
                                Text(insight.category)
                                    .font(.subheadline)
                                    .textCase(.uppercase)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        
                        Divider()
                        
                        // Description
                        Text("Analysis")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                        
                        Text(insight.description)
                            .font(.body)
                        
                        Divider()
                        
                        // Glucose Visualization (if blood sugar related)
                        if insight.type == .bloodSugar {
                            Text("Glucose Trends")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            
                            // Time Selector
                            Picker("Timeframe", selection: $selectedTimeframe) {
                                ForEach(Timeframe.allCases, id: \.self) { timeframe in
                                    Text(timeframe.rawValue).tag(timeframe)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(.bottom)
                            
                            // Sample glucose chart
                            GlucoseChartView(timeframe: selectedTimeframe)
                                .frame(height: 200)
                                .padding(.bottom)
                            
                            Divider()
                        }
                        
                        // Action Items
                        if !insight.actionItems.isEmpty {
                            Text("Recommended Actions")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(insight.actionItems, id: \.self) { action in
                                    HStack(alignment: .top) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                            .font(.body)
                                        
                                        Text(action)
                                            .font(.body)
                                    }
                                }
                            }
                            
                            Divider()
                        }
                        
                        // Data Visualization
                        if !insight.dataPoints.isEmpty {
                            Text("Data Points")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            
                            // Chart for data points
                            Chart {
                                ForEach(Array(insight.dataPoints.keys.sorted()), id: \.self) { key in
                                    if let value = insight.dataPoints[key] {
                                        BarMark(
                                            x: .value("Category", key.capitalized),
                                            y: .value("Value", value)
                                        )
                                        .foregroundStyle(insight.priorityColor.gradient)
                                    }
                                }
                            }
                            .frame(height: 200)
                            .padding(.bottom)
                        }
                    }
                    .padding()
                }
                .navigationTitle("Insight Details")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
    
    struct GlucoseChartView: View {
        let timeframe: InsightDetailView.Timeframe
        
        // Sample data for preview
        let sampleData: [(Date, Double)] = (0..<24).map { hour in
            let date = Calendar.current.date(byAdding: .hour, value: -hour, to: Date())!
            let value = Double.random(in: 80...200)
            return (date, value)
        }
        
        var body: some View {
            Chart {
                ForEach(sampleData, id: \.0) { item in
                    LineMark(
                        x: .value("Time", item.0),
                        y: .value("Glucose", item.1)
                    )
                    .foregroundStyle(.red.gradient)
                    .interpolationMethod(.catmullRom)
                    
                    AreaMark(
                        x: .value("Time", item.0),
                        y: .value("Glucose", item.1)
                    )
                    .foregroundStyle(.red.opacity(0.1))
                    .interpolationMethod(.catmullRom)
                }
                
                // Target range
                RectangleMark(
                    yStart: 70,
                    yEnd: 180
                )
                .foregroundStyle(.green.opacity(0.1))
            }
            .chartYScale(domain: 40...300)
            .chartXAxis {
                AxisMarks(values: .stride(by: timeframe == .day ? 4 : 24)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.hour())
                }
            }
            .chartYAxis {
                AxisMarks(values: .stride(by: 50)) { value in
                    AxisGridLine()
                    AxisValueLabel()
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
                        
                        ForEach(insight.actionItems.prefix(2), id: \.self) { action in
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
                        
                        if insight.actionItems.count > 2 {
                            Text("... and \(insight.actionItems.count - 2) more")
                                .font(.caption)
                                .foregroundStyle(.secondary)
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
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
    }
    
    struct AIInsightsView_Previews: PreviewProvider {
        static var previews: some View {
            NavigationStack {
                AIInsightsView()
                    .environmentObject(APIManager())
            }
        }
    }
}
