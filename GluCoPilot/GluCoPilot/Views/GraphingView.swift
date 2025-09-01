import SwiftUI
import Charts

struct GraphingView: View {
    @EnvironmentObject private var apiManager: APIManager
    @EnvironmentObject private var dexcomManager: DexcomManager
    @EnvironmentObject private var healthKitManager: HealthKitManager
    @State private var selectedTimeframe: Timeframe = .day
    @State private var showGlucose: Bool = true
    @State private var showFood: Bool = true
    @State private var showWorkouts: Bool = true
    @State private var isLoading: Bool = false
    @State private var glucoseReadings: [GlucoseReading] = []
    @State private var foodEntries: [FoodEntry] = []
    @State private var workouts: [WorkoutData] = []
    @State private var error: String? = nil
    @State private var dataSource: DataSource = .dexcom
    
    enum DataSource: String, CaseIterable, Identifiable {
        case dexcom = "Dexcom"
        case healthKit = "HealthKit"
        case sample = "Sample Data"
        
        var id: String { self.rawValue }
    }
    
    enum Timeframe: String, CaseIterable, Identifiable {
        case day = "24h"
        case week = "7d"
        case month = "30d"
        
        var id: String { self.rawValue }
        
        var title: String {
            switch self {
            case .day: return "Day"
            case .week: return "Week"
            case .month: return "Month"
            }
        }
        
        var hours: Int {
            switch self {
            case .day: return 24
            case .week: return 24 * 7
            case .month: return 24 * 30
            }
        }
        
        var apiString: String {
            switch self {
            case .day: return "1d"
            case .week: return "7d"
            case .month: return "30d"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue.gradient)
                        
                        Text("Glucose & Health Data")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        Text("Visualize your glucose levels alongside food and activity")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    // Data Source Selector
                    VStack(alignment: .leading) {
                        Text("Data Source")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        Picker("Data Source", selection: $dataSource) {
                            if dexcomManager.isConnected {
                                Text("Dexcom").tag(DataSource.dexcom)
                            }
                            Text("HealthKit").tag(DataSource.healthKit)
                            Text("Sample Data").tag(DataSource.sample)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .onChange(of: dataSource) { _, _ in
                            loadData()
                        }
                    }
                    
                    // Timeframe Selector
                    Picker("Timeframe", selection: $selectedTimeframe) {
                        ForEach(Timeframe.allCases) { timeframe in
                            Text(timeframe.title).tag(timeframe)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .onChange(of: selectedTimeframe) { _, _ in
                        loadData()
                    }
                    
                    // Data Toggle Options
                    HStack {
                        DataToggle(isEnabled: $showGlucose, label: "Glucose", color: .red)
                        DataToggle(isEnabled: $showFood, label: "Food", color: .green)
                        DataToggle(isEnabled: $showWorkouts, label: "Activity", color: .orange)
                    }
                    .padding(.horizontal)
                    
                    // Main Chart
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Combined Data View")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        if isLoading {
                            ProgressView()
                                .frame(height: 300)
                        } else if let errorMessage = error {
                            VStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .font(.largeTitle)
                                    .foregroundColor(.orange)
                                Text("Error loading data")
                                    .font(.headline)
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(height: 300)
                            .frame(maxWidth: .infinity)
                        } else if glucoseReadings.isEmpty && foodEntries.isEmpty && workouts.isEmpty {
                            VStack {
                                Image(systemName: "chart.bar.xaxis")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                                Text("No data available")
                                    .font(.headline)
                                Text("Sync your health data to see charts")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .frame(height: 300)
                            .frame(maxWidth: .infinity)
                        } else {
                            // Main Chart
                            CombinedDataChart(
                                glucoseReadings: glucoseReadings,
                                foodEntries: foodEntries,
                                workouts: workouts,
                                showGlucose: showGlucose,
                                showFood: showFood,
                                showWorkouts: showWorkouts,
                                timeframe: selectedTimeframe
                            )
                            .frame(height: 300)
                            .padding(.horizontal)
                        }
                    }
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                    .padding(.horizontal)
                    
                    // Glucose Stats Card
                    if showGlucose && !glucoseReadings.isEmpty {
                        GlucoseStatsCard(readings: glucoseReadings)
                            .padding(.horizontal)
                    }
                    
                    // Food Log
                    if showFood && !foodEntries.isEmpty {
                        FoodLogCard(entries: foodEntries)
                            .padding(.horizontal)
                    }
                    
                    // Activity Log
                    if showWorkouts && !workouts.isEmpty {
                        WorkoutLogCard(workouts: workouts)
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Glucose & Health")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .refreshable {
                await loadDataAsync()
            }
            .onAppear {
                loadData()
            }
        }
    }
    
    private func loadData() {
        isLoading = true
        error = nil
        
        Task {
            await loadDataAsync()
        }
    }
    
    private func loadDataAsync() async {
        do {
            await MainActor.run {
                error = nil
            }
            
            switch dataSource {
            case .dexcom:
                if dexcomManager.isConnected {
                    // Fetch Dexcom data from the backend API
                    let readings = try await dexcomManager.fetchGlucoseReadings(
                        timeframe: selectedTimeframe.apiString,
                        count: selectedTimeframe == .day ? 24 : (selectedTimeframe == .week ? 168 : 720),
                        apiManager: apiManager
                    )
                    
                    await MainActor.run {
                        glucoseReadings = readings
                    }
                } else {
                    await MainActor.run {
                        error = "Dexcom is not connected. Please connect Dexcom or choose a different data source."
                        dataSource = .healthKit // Fallback to HealthKit
                    }
                    return
                }
                
            case .healthKit:
                // Fetch HealthKit data
                if healthKitManager.authorizationStatus == .sharingAuthorized {
                    let endDate = Date()
                    let startDate = Calendar.current.date(
                        byAdding: .hour,
                        value: -selectedTimeframe.hours,
                        to: endDate
                    )!
                    
                    let readings = try await healthKitManager.fetchGlucoseReadings(
                        from: startDate,
                        to: endDate
                    )
                    
                    await MainActor.run {
                        glucoseReadings = readings
                    }
                } else {
                    await MainActor.run {
                        error = "HealthKit is not authorized. Please authorize HealthKit access or choose a different data source."
                        dataSource = .sample // Fallback to sample data
                    }
                    return
                }
                
            case .sample:
                // Generate sample data
                generateSampleData()
            }
            
            // Fetch food and workout data from HealthKit regardless of glucose data source
            if healthKitManager.authorizationStatus == .sharingAuthorized {
                let endDate = Date()
                let startDate = Calendar.current.date(
                    byAdding: .hour,
                    value: -selectedTimeframe.hours,
                    to: endDate
                )!
                
                // In a real implementation, we would fetch this data from HealthKit
                // For now, we'll continue using sample data for food and workouts
            }
            
            await MainActor.run {
                isLoading = false
            }
        } catch {
            await MainActor.run {
                self.error = error.localizedDescription
                self.isLoading = false
                
                // If Dexcom or HealthKit fails, fall back to sample data
                if self.dataSource != .sample {
                    self.dataSource = .sample
                    Task {
                        await self.loadDataAsync()
                    }
                }
            }
        }
    }
    
    private func generateSampleData() {
        // Generate sample glucose readings
        let hoursToGenerate = selectedTimeframe.hours
        var newGlucoseReadings: [GlucoseReading] = []
        var newFoodEntries: [FoodEntry] = []
        var newWorkouts: [WorkoutData] = []
        
        // Generate glucose readings (one per hour)
        for hour in 0..<hoursToGenerate {
            let date = Calendar.current.date(byAdding: .hour, value: -hour, to: Date())!
            
            // Vary glucose based on time of day
            let hourOfDay = Calendar.current.component(.hour, from: date)
            var baseValue = 120.0
            
            // Higher in morning, lower at night
            if hourOfDay >= 6 && hourOfDay <= 10 {
                baseValue = 140.0 // Dawn phenomenon
            } else if hourOfDay >= 11 && hourOfDay <= 14 {
                baseValue = 130.0 // Lunch time
            } else if hourOfDay >= 17 && hourOfDay <= 20 {
                baseValue = 135.0 // Dinner time
            } else if hourOfDay >= 21 || hourOfDay <= 5 {
                baseValue = 110.0 // Overnight
            }
            
            // Add some randomness
            let value = Int(baseValue + Double.random(in: -20...20))
            
            // Determine trend
            let trend: String
            let previousValue = newGlucoseReadings.last?.value ?? value
            let difference = value - previousValue
            
            if difference > 15 {
                trend = "rising_quickly"
            } else if difference > 5 {
                trend = "rising"
            } else if difference > -5 {
                trend = "flat"
            } else if difference > -15 {
                trend = "falling"
            } else {
                trend = "falling_quickly"
            }
            
            let reading = GlucoseReading(
                id: UUID(),
                value: value,
                trend: trend,
                timestamp: date,
                unit: "mg/dL"
            )
            
            newGlucoseReadings.append(reading)
        }
        
        // Generate food entries (3 per day)
        let daysToGenerate = hoursToGenerate / 24
        for day in 0..<daysToGenerate {
            // Breakfast
            let breakfastTime = Calendar.current.date(byAdding: .hour, value: -(day * 24 + 8), to: Date())!
            newFoodEntries.append(FoodEntry(
                name: "Breakfast",
                calories: Double.random(in: 300...600),
                carbs: Double.random(in: 30...60),
                protein: Double.random(in: 10...25),
                fat: Double.random(in: 5...20),
                timestamp: breakfastTime
            ))
            
            // Lunch
            let lunchTime = Calendar.current.date(byAdding: .hour, value: -(day * 24 + 13), to: Date())!
            newFoodEntries.append(FoodEntry(
                name: "Lunch",
                calories: Double.random(in: 400...800),
                carbs: Double.random(in: 40...80),
                protein: Double.random(in: 20...40),
                fat: Double.random(in: 10...30),
                timestamp: lunchTime
            ))
            
            // Dinner
            let dinnerTime = Calendar.current.date(byAdding: .hour, value: -(day * 24 + 18), to: Date())!
            newFoodEntries.append(FoodEntry(
                name: "Dinner",
                calories: Double.random(in: 500...900),
                carbs: Double.random(in: 40...90),
                protein: Double.random(in: 25...50),
                fat: Double.random(in: 15...35),
                timestamp: dinnerTime
            ))
        }
        
        // Generate workouts (1 per day)
        for day in 0..<daysToGenerate {
            let workoutTime = Calendar.current.date(byAdding: .hour, value: -(day * 24 + 17), to: Date())!
            let duration = TimeInterval.random(in: 1800...3600) // 30-60 minutes
            let endTime = workoutTime.addingTimeInterval(duration)
            
            let workoutTypes = ["Walking", "Running", "Cycling", "Strength Training", "Swimming"]
            let randomType = workoutTypes.randomElement() ?? "Walking"

            newWorkouts.append(WorkoutData(
                type: randomType,
                duration: duration,
                calories: Double.random(in: 150...600),
                startDate: workoutTime,
                endDate: endTime
            ))
        }
        
        // Sort everything by timestamp
        Task { @MainActor in
            glucoseReadings = newGlucoseReadings.sorted(by: { $0.timestamp > $1.timestamp })
            foodEntries = newFoodEntries.sorted(by: { $0.timestamp > $1.timestamp })
            workouts = newWorkouts.sorted(by: { $0.startDate > $1.startDate })
        }
    }
}

struct CombinedDataChart: View {
    let glucoseReadings: [GlucoseReading]
    let foodEntries: [FoodEntry]
    let workouts: [WorkoutData]
    let showGlucose: Bool
    let showFood: Bool
    let showWorkouts: Bool
    let timeframe: GraphingView.Timeframe
    
    var body: some View {
        Chart {
            // Target range for glucose
            if showGlucose {
                RectangleMark(
                    yStart: 70,
                    yEnd: 180
                )
                .foregroundStyle(.green.opacity(0.1))
                .annotation(position: .trailing) {
                    Text("Target")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
            }
            
            // Glucose Readings
            if showGlucose {
                ForEach(glucoseReadings) { reading in
                    LineMark(
                        x: .value("Time", reading.timestamp),
                        y: .value("Glucose", reading.value)
                    )
                    .foregroundStyle(.red.gradient)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)
                    
                    PointMark(
                        x: .value("Time", reading.timestamp),
                        y: .value("Glucose", reading.value)
                    )
                    .foregroundStyle(.red)
                    .symbolSize(20)
                }
            }
            
            // Food Entries
            if showFood {
                ForEach(foodEntries) { entry in
                    BarMark(
                        x: .value("Time", entry.timestamp),
                        y: .value("Carbs", entry.carbs * 2) // Scale for visibility
                    )
                    .foregroundStyle(.green.opacity(0.7))
                    .annotation(position: .top) {
                        Text("\(Int(entry.carbs))g")
                            .font(.system(size: 8))
                            .foregroundStyle(.green)
                    }
                }
            }
            
            // Workouts
            if showWorkouts {
                ForEach(workouts) { workout in
                    RectangleMark(
                        xStart: .value("Start", workout.startDate),
                        xEnd: .value("End", workout.endDate),
                        yStart: 50,
                        yEnd: 60
                    )
                    .foregroundStyle(.orange.opacity(0.5))
                    .annotation(position: .top) {
                        Text(workout.type.prefix(1))
                            .font(.system(size: 8))
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .chartYScale(domain: 40...300)
        .chartXAxis {
            AxisMarks(values: .automatic) { value in
                if let date = value.as(Date.self) {
                    let hour = Calendar.current.component(.hour, from: date)
                    let isAxisLabelHour = timeframe == .day ? hour % 4 == 0 : hour == 0
                    
                    if isAxisLabelHour {
                        AxisGridLine()
                        AxisValueLabel {
                            if timeframe == .day {
                                Text(date, format: .dateTime.hour())
                            } else {
                                Text(date, format: .dateTime.month().day())
                            }
                        }
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(values: .stride(by: 50)) { value in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .chartLegend(position: .bottom, alignment: .center, spacing: 20) {
            HStack(spacing: 20) {
                if showGlucose {
                    LegendItem(color: .red, label: "Glucose")
                }
                if showFood {
                    LegendItem(color: .green, label: "Carbs")
                }
                if showWorkouts {
                    LegendItem(color: .orange, label: "Activity")
                }
            }
        }
    }
}

struct DataToggle: View {
    @Binding var isEnabled: Bool
    let label: String
    let color: Color
    
    var body: some View {
        Toggle(isOn: $isEnabled) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)
                Text(label)
                    .font(.subheadline)
            }
        }
        .toggleStyle(.switch)
    }
}

struct LegendItem: View {
    let color: Color
    let label: String
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct GlucoseStatsCard: View {
    let readings: [GlucoseReading]
    
    var averageGlucose: Int {
        guard !readings.isEmpty else { return 0 }
        let sum = readings.reduce(0) { $0 + $1.value }
        return Int(Double(sum) / Double(readings.count))
    }
    
    var minGlucose: Int {
        readings.min(by: { $0.value < $1.value })?.value ?? 0
    }
    
    var maxGlucose: Int {
        readings.max(by: { $0.value < $1.value })?.value ?? 0
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Glucose Statistics")
                .font(.headline)
            
            HStack(spacing: 20) {
                StatItem(label: "Average", value: "\(averageGlucose)", unit: "mg/dL", color: .blue)
                StatItem(label: "Lowest", value: "\(minGlucose)", unit: "mg/dL", color: .green)
                StatItem(label: "Highest", value: "\(maxGlucose)", unit: "mg/dL", color: .red)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct StatItem: View {
    let label: String
    let value: String
    let unit: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .center, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
            
            Text(unit)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct FoodLogCard: View {
    let entries: [FoodEntry]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Food Log")
                .font(.headline)
            
            VStack(spacing: 12) {
                ForEach(Array(entries.prefix(3)).indices, id: \.self) { idx in
                    let entry = entries[idx]
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Text(entry.timestamp, format: .dateTime.hour().minute())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(Int(entry.calories)) cal")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Text("C: \(Int(entry.carbs))g • P: \(Int(entry.protein))g • F: \(Int(entry.fat))g")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    if idx < min(entries.count, 3) - 1 {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct WorkoutLogCard: View {
    let workouts: [WorkoutData]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activities")
                .font(.headline)
            
            VStack(spacing: 12) {
                ForEach(Array(workouts.prefix(3)).indices, id: \.self) { idx in
                    let workout = workouts[idx]
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(workout.type)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Text(workout.startDate, format: .dateTime.month().day().hour())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(Int(workout.duration / 60)) min")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            if let calories = workout.calories {
                                Text("\(Int(calories)) calories burned")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    
                    if idx < min(workouts.count, 3) - 1 {
                        Divider()
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

#Preview {
    GraphingView()
        .environmentObject(APIManager())
}
