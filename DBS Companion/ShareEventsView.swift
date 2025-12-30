import SwiftUI

struct ShareEventsView: View {
    let events: [Event]

    @State private var format: ShareFormat = .plainText

    private var tableDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Format", selection: $format) {
                ForEach(ShareFormat.allCases) { format in
                    Text(format.label).tag(format)
                }
            }
            .pickerStyle(.segmented)

            List {
                HStack {
                    Text("Time")
                        .font(.headline)
                    Spacer()
                    Text("Event")
                        .font(.headline)
                }
                .padding(.vertical, 4)

                ForEach(events) { event in
                    HStack {
                        Text(tableDateFormatter.string(from: event.timestamp))
                        Spacer()
                        Text(event.type.displayName)
                    }
                    .padding(.vertical, 6)
                }
            }
            .listStyle(.plain)

            ShareLink(item: format.payload(for: events), preview: SharePreview("DBS Companion")) {
                Label("Share", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .navigationTitle("Share")
        .navigationBarTitleDisplayMode(.inline)
    }
}

enum ShareFormat: String, CaseIterable, Identifiable {
    case plainText
    case csv

    var id: String { rawValue }

    var label: String {
        switch self {
        case .plainText:
            "Plain Text"
        case .csv:
            "CSV"
        }
    }

    func payload(for events: [Event]) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "HH:mm"
        let sortedEvents = events.sorted { $0.timestamp < $1.timestamp }
        switch self {
        case .plainText:
            return sortedEvents.map { "\(dateFormatter.string(from: $0.timestamp)) – \($0.type.displayName)" }.joined(separator: "\n")
        case .csv:
            let rows = sortedEvents.map { "\(dateFormatter.string(from: $0.timestamp)),\($0.type.displayName)" }
            return (["Time,Event"] + rows).joined(separator: "\n")
        }
    }
}

#Preview {
    let events = [
        Event(timestamp: .now, type: .dystonia),
        Event(timestamp: .now.addingTimeInterval(-5000), type: .wearingOff)
    ]
    NavigationStack {
        ShareEventsView(events: events)
    }
}
