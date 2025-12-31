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

    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }

    var body: some View {
        List(selection: $selected) {
            ForEach(sectionedEvents, id: \.date) { section in
                Section(header: Text(dayFormatter.string(from: section.date))) {
                    ForEach(section.events) { event in
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

    private var sectionedEvents: [(date: Date, events: [Event])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: events) { event in
            calendar.startOfDay(for: event.timestamp)
        }
        let sortedKeys = grouped.keys.sorted(by: >)
        return sortedKeys.map { key in
            let dayEvents = (grouped[key] ?? []).sorted { $0.timestamp > $1.timestamp }
            return (date: key, events: dayEvents)
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
