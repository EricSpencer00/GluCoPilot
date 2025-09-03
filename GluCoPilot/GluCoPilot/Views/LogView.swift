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
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.blue)
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .padding(.horizontal)

                    // Recent cached items (last 24h)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent Logs (24h)")
                            .font(.headline)
                            .padding(.horizontal)

                        ForEach(cache.getItems(since: Calendar.current.date(byAdding: .hour, value: -24, to: Date())!)) { item in
                            HStack {
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
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 8).fill(.ultraThinMaterial))
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Log")
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
}

struct LogView_Previews: PreviewProvider {
    static var previews: some View {
        LogView()
            .environmentObject(CacheManager.shared)
    }
}
