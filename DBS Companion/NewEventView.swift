import SwiftUI
import SwiftData

struct NewEventView: View {
    @Environment(\.dismiss) private var dismiss

    let inputMethod: AddEventInputMethod
    var onSave: (Event) -> Void

    @State private var timestamp = Date()
    @State private var eventType: EventType?
    @State private var subtype = ""
    @State private var notes = ""

    private var isValid: Bool { eventType != nil }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/YYYY h:mm a"
        return formatter
    }

    var body: some View {
        Form {
            Section(header: Text("Time")) {
                DatePicker("", selection: $timestamp)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                Text(dateFormatter.string(from: timestamp))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(header: Text("Type")) {
                Picker("Event type", selection: Binding<EventType?>(get: { eventType }, set: { eventType = $0 })) {
                    Text("Select type").tag(Optional<EventType>.none)
                    ForEach(EventType.allCases) { type in
                        Text(type.displayName).tag(Optional(type))
                    }
                }
                .pickerStyle(.navigationLink)
            }

            Section(header: Text("Sub-type (optional)")) {
                TextField("Shoulder Pull", text: $subtype)
            }

            Section(header: Text("Notes")) {
                TextField("Shoulder pulls forward causing winging scapula", text: $notes, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section(header: Text("Input method")) {
                Label(inputMethod.label, systemImage: inputMethod.icon)
            }
        }
        .navigationTitle("New event")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Save") {
                    guard let eventType else { return }
                    let event = Event(timestamp: timestamp, type: eventType, subtype: subtype.isEmpty ? nil : subtype, notes: notes.isEmpty ? nil : notes)
                    onSave(event)
                    dismiss()
                }
                .disabled(!isValid)
            }
        }
    }
}

#Preview {
    NavigationStack {
        NewEventView(inputMethod: .text) { _ in }
    }
}
