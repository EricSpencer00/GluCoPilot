import SwiftUI

struct PayloadViewerView: View {
    let payload: [String: Any]
    let title: String
    
    // Render pretty JSON string for display
    private var prettyJSON: String {
        guard JSONSerialization.isValidJSONObject(payload) else { return "<invalid JSON payload>" }
        if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys]), let str = String(data: data, encoding: .utf8) {
            return str
        }
        return "<unable to format payload>"
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                Text(prettyJSON)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct PayloadViewerView_Previews: PreviewProvider {
    static var previews: some View {
        PayloadViewerView(payload: ["example": ["a": 1, "b": 2]], title: "Payload")
    }
}
