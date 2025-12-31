import SwiftUI
import SwiftData

struct EventDetailView: View {
    @Environment(\.dismiss) private var dismiss

    @Bindable var event: Event
    @State private var isEditing = false

    private var subtypeBinding: Binding<String> {
        Binding<String>(
            get: { event.subtype ?? "" },
            set: { event.subtype = $0.isEmpty ? nil : $0 }
        )
    }

    private var notesBinding: Binding<String> {
        Binding<String>(
            get: { event.notes ?? "" },
            set: { event.notes = $0.isEmpty ? nil : $0 }
        )
    }

    private var limitedNotesBinding: Binding<String> {
        Binding<String>(
            get: { notesBinding.wrappedValue },
            set: { newValue in
                notesBinding.wrappedValue = String(newValue.prefix(200))
            }
        )
    }

    var body: some View {
        Form {
            Section(header: Text("Time")) {
                DatePicker("", selection: Binding(get: { event.timestamp }, set: { _ in }), displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .disabled(true)
            }

            Section(header: Text("Type")) {
                HStack {
                    Text(event.type.displayName)
                    Spacer()
                }
            }

            Section(header: Text("Details")) {
                TextField("For example: \"Shoulder pulls forward\"", text: subtypeBinding)
                    .disabled(!isEditing)
            }

            Section(header: Text("Notes")) {
                TextField("Enter event notese here", text: limitedNotesBinding, axis: .vertical)
                    .lineLimit(3...6)
                    .disabled(!isEditing)
            }
        }
        .navigationTitle("Event")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isEditing ? "Done" : "Edit") {
                    isEditing.toggle()
                }
            }
        }
    }
}

#Preview {
    let event = Event(timestamp: .now, type: .dystonia, subtype: "For example: \"Shoulder pulls forward\"", notes: "Sample notes")
    NavigationStack {
        EventDetailView(event: event)
            .modelContainer(for: Event.self, inMemory: true)
    }
}
