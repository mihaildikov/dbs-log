import SwiftUI

struct SelectEventsView: View {
    let events: [Event]
    var onShare: (Set<UUID>) -> Void

    @State private var selected = Set<UUID>()

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }

    var body: some View {
        List(selection: $selected) {
            ForEach(events) { event in
                HStack(spacing: 12) {
                    Image(systemName: selected.contains(event.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selected.contains(event.id) ? .blue : .secondary)
                    EventRow(event: event, timeFormatter: timeFormatter)
                        .padding(.vertical, 2)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    toggle(event.id)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle("Select events")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Share") {
                    onShare(selected)
                }
                .disabled(selected.isEmpty)
            }
        }
    }

    private func toggle(_ id: UUID) {
        if selected.contains(id) {
            selected.remove(id)
        } else {
            selected.insert(id)
        }
    }
}

#Preview {
    let events = [
        Event(timestamp: .now, type: .dyskinesia),
        Event(timestamp: .now.addingTimeInterval(-3600), type: .dystonia)
    ]
    NavigationStack {
        SelectEventsView(events: events) { _ in }
    }
}
