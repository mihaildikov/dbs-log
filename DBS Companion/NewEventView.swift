import SwiftUI
import SwiftData

struct NewEventView: View {
    @Environment(\.dismiss) private var dismiss

    let mode: NewEventMode
    let inputMethod: AddEventInputMethod
    var onSave: (Event) -> Void

    @State private var timestamp = Date()
    @State private var eventType: EventType?
    @State private var subtype = ""
    @State private var notes = ""
    @State private var warnings: [String] = []

    @StateObject private var transcriber = SpeechTranscriber()
    private let parser = EventTranscriptParser()

    private var isValid: Bool { eventType != nil }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/YYYY h:mm a"
        return formatter
    }

    var body: some View {
        Form {
            if mode == .voice {
                voiceRecorderSection
            }

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

            if !warnings.isEmpty {
                Section(header: Text("Parse warnings")) {
                    ForEach(warnings, id: \.self) { warning in
                        Text(warning)
                            .foregroundStyle(.orange)
                    }
                }
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
                .disabled(!isValid || transcriber.state == .processing)
            }
        }
        .onAppear {
            transcriber.onFinalTranscription = applyTranscript
        }
    }

    private var voiceRecorderSection: some View {
        Section {
            VStack(spacing: 12) {
                Button(action: toggleRecording) {
                    HStack {
                        Image(systemName: transcriber.state == .recording ? "stop.fill" : "mic.circle.fill")
                            .font(.largeTitle)
                        Text(transcriber.state == .recording ? "Stop" : "Record")
                            .font(.headline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(transcriber.state == .recording ? .red : .blue)

                HStack {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 10, height: 10)
                    Text(statusText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(transcriptTitle)
                        .font(.subheadline.weight(.semibold))
                    ScrollView {
                        Text(transcriber.transcript.isEmpty ? "Tap record and start speaking." : transcriber.transcript)
                            .font(.body.monospaced())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(10)
                            .background(Color(UIColor.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .frame(minHeight: 80, maxHeight: 140)
                }

                if case .error(let message) = transcriber.state {
                    Text(message)
                        .foregroundStyle(.red)
                        .font(.footnote)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var statusColor: Color {
        switch transcriber.state {
        case .idle:
            .gray
        case .recording:
            .red
        case .processing:
            .blue
        case .error:
            .orange
        }
    }

    private var statusText: String {
        switch transcriber.state {
        case .idle:
            "Idle"
        case .recording:
            "Recording"
        case .processing:
            "Processing"
        case .error:
            "Error"
        }
    }

    private var transcriptTitle: String {
        switch transcriber.state {
        case .idle:
            "Transcript"
        case .recording:
            "Listening…"
        case .processing:
            "Transcribing…"
        case .error:
            "Transcript (partial)"
        }
    }

    private func toggleRecording() {
        switch transcriber.state {
        case .recording:
            transcriber.stopRecording()
        case .processing:
            break
        case .idle, .error:
            transcriber.startRecording()
        }
    }

    private func applyTranscript(_ transcript: String) {
        let parsed = parser.parse(transcript)
        warnings = parsed.parseWarnings
        if let parsedType = parsed.type {
            eventType = parsedType
        }
        if let parsedSubtype = parsed.subtype {
            subtype = parsedSubtype
        }
        if let parsedTime = parsed.timestamp {
            timestamp = parsedTime
        }

        let parsedNotes = parsed.notes ?? parsed.rawTranscript
        if notes.isEmpty {
            notes = parsedNotes
        } else {
            notes += "\n" + parsedNotes
        }
    }
}

#Preview {
    NavigationStack {
        NewEventView(mode: .voice, inputMethod: .voice) { _ in }
    }
}
