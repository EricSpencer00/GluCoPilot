import SwiftUI

struct LogView: View {
    @StateObject private var cache = CacheManager.shared
    @State private var selectedType: String = "food"
    @State private var valueField: String = ""
    @State private var noteField: String = ""
    @State private var carbsField: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Top decorative gradient area
                    ZStack {
                        Color.clear.frame(height: 0)
                    }
                    Picker("Type", selection: $selectedType) {
                        Text("Food").tag("food")
                        Text("Insulin").tag("insulin")
                        Text("Other").tag("other")
                    }
                    .pickerStyle(.segmented)
                    .padding()

                    if selectedType == "food" {
                        VStack(spacing: 8) {
                            TextField("Meal description", text: $valueField)
                                .textFieldStyle(.roundedBorder)
                            TextField("Carbs (g)", text: $carbsField)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                        }
                        .padding(.horizontal)
                    } else if selectedType == "insulin" {
                        VStack(spacing: 8) {
                            TextField("Insulin dose (units)", text: $valueField)
                                .keyboardType(.decimalPad)
                                .textFieldStyle(.roundedBorder)
                            TextField("Notes (e.g. correction)", text: $noteField)
                                .textFieldStyle(.roundedBorder)
                        }
                        .padding(.horizontal)
                    } else {
                        TextField("Note", text: $noteField)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal)
                    }

                    Button(action: addLog) {
                        Text("Add Log")
                            .font(.headline)
                    }
                    .buttonStyle(GradientButtonStyle(colors: [Color.blue, Color.purple]))
                    .padding(.horizontal)
                    .padding(.horizontal)

                    // Recent cached items (last 24h)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Recent Logs (24h)")
                                .font(.headline)
                            Spacer()
                        }
                        .padding(.horizontal)

                        ForEach(cache.getItems(since: Calendar.current.date(byAdding: .hour, value: -24, to: Date())!)) { item in
                            HStack(alignment: .top, spacing: 12) {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.secondary.opacity(0.12))
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Image(systemName: iconForType(item.type))
                                            .foregroundColor(colorForType(item.type))
                                    )

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.type.capitalized)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                    Text(item.payload.map { "\($0.key): \($0.value)" }.joined(separator: ", "))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Text(item.timestamp, style: .relative)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Log")
            .withTopGradient()
        }
    }

    private func addLog() {
        let now = Date()
        switch selectedType {
        case "food":
            let payload: [String: String] = ["description": valueField, "carbs": carbsField]
            cache.log(type: "food", payload: payload, at: now)
            valueField = ""
            carbsField = ""
        case "insulin":
            let payload: [String: String] = ["dose": valueField, "note": noteField]
            cache.log(type: "insulin", payload: payload, at: now)
            valueField = ""
            noteField = ""
        default:
            let payload: [String: String] = ["note": noteField]
            cache.log(type: "other", payload: payload, at: now)
            noteField = ""
        }
    }

    private func iconForType(_ type: String) -> String {
        switch type.lowercased() {
        case "food": return "fork.knife"
        case "insulin": return "syringe"
        default: return "note.text"
        }
    }

    private func colorForType(_ type: String) -> Color {
        switch type.lowercased() {
        case "food": return .orange
        case "insulin": return .pink
        default: return .blue
        }
    }
}

struct LogView_Previews: PreviewProvider {
    static var previews: some View {
        LogView()
            .environmentObject(CacheManager.shared)
    }
}
