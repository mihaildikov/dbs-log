import SwiftUI
import SwiftData

struct NewEventView: View {
    @Environment(\.dismiss) private var dismiss

    let mode: NewEventMode
    var initialDraft: ParsedEventDraft? = nil
    var autoStartVoice: Bool = false
    var onSave: (Event) -> Void

    @State private var timestamp = Date()
    @State private var eventType: EventType?
    @State private var subtype = ""
    @State private var notes = ""
    @State private var warnings: [String] = []
    @State private var didApplyDraft = false
    @State private var detectedDraft: ParsedEventDraft?
    @State private var didApplyUITestOverrides = false

    private static var uiTestTimeOverrides: [Date] = {
        guard ProcessInfo.processInfo.arguments.contains("UITests"),
              let raw = ProcessInfo.processInfo.environment["DBS_UI_TEST_TIMES"],
              !raw.isEmpty
        else { return [] }

        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let calendar = Calendar.current
        let baseDate = Date()
        let dateParts = calendar.dateComponents([.year, .month, .day], from: baseDate)

        return raw.split(separator: "|").compactMap { value in
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let timeDate = formatter.date(from: trimmed) else { return nil }
            let timeParts = calendar.dateComponents([.hour, .minute], from: timeDate)
            var combined = DateComponents()
            combined.year = dateParts.year
            combined.month = dateParts.month
            combined.day = dateParts.day
            combined.hour = timeParts.hour
            combined.minute = timeParts.minute
            return calendar.date(from: combined)
        }
    }()
    private static var uiTestTimeIndex = 0

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
                    .accessibilityIdentifier("timestampPicker")
                Text(dateFormatter.string(from: timestamp))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section(header: Text("Type")) {
                let selectableTypes = EventType.allCases
                Picker("Event type", selection: Binding<EventType?>(get: { eventType }, set: { eventType = $0 })) {
                    Text("Select type").tag(Optional<EventType>.none)
                    ForEach(selectableTypes) { type in
                        Text(type.displayName)
                            .tag(Optional(type))
                            .accessibilityIdentifier("eventTypeOption_\(type.rawValue)")
                    }
                }
                .pickerStyle(.navigationLink)
                .accessibilityIdentifier("eventTypePicker")
            }

            Section(header: Text("Details (optional)")) {
                TextField("For example: \"Shoulder pulls forward\"", text: $subtype)
                    .accessibilityIdentifier("eventSubtypeField")
            }

            Section(header: Text("Notes")) {
                TextField("For example: \"Shoulder pulls forward\"", text: limitedNotesBinding, axis: .vertical)
                    .lineLimit(3...6)
                    .accessibilityIdentifier("eventNotesField")
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
                .accessibilityIdentifier("saveEventButton")
            }
        }
        .onAppear {
            transcriber.onFinalTranscription = applyTranscript
            applyInitialDraftIfNeeded()
            applyUITestOverridesIfNeeded()
        }
        .onChange(of: transcriber.transcript) { _, latest in
            guard transcriber.state == .recording || transcriber.state == .processing else { return }
            detectedDraft = parser.parse(latest)
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

                    if let detectedDraft {
                        detectedHighlights(for: detectedDraft)
                    }
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

    @ViewBuilder
    private func detectedHighlights(for draft: ParsedEventDraft) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if let type = draft.type {
                highlightRow(label: "Type", value: type.displayName)
            }
            if let subtype = draft.subtype, !subtype.isEmpty {
                highlightRow(label: "Details", value: subtype)
            }
            if let notes = draft.notes, !notes.isEmpty {
                highlightRow(label: "Notes", value: notes)
            }
        }
    }

    private func highlightRow(label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption.weight(.bold))
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Color.blue)
                .foregroundStyle(.white)
                .clipShape(Capsule())

            Text(value)
                .font(.caption)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(Color.blue.opacity(0.15))
                .clipShape(Capsule())
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
        detectedDraft = parsed
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

        let parsedNotes = parsed.notes ?? parsed.rawText
        if notes.isEmpty {
            notes = truncatedNotes(from: parsedNotes)
        } else {
            let combined = notes + "\n" + parsedNotes
            notes = truncatedNotes(from: combined)
        }
    }

    private func applyInitialDraftIfNeeded() {
        guard !didApplyDraft, let initialDraft else { return }
        didApplyDraft = true
        detectedDraft = initialDraft

        if let draftType = initialDraft.type { eventType = draftType }
        if let draftSubtype = initialDraft.subtype { subtype = draftSubtype }
        if let draftTime = initialDraft.timestamp { timestamp = draftTime }

        var draftNotes: [String] = []
        if let source = initialDraft.source { draftNotes.append("Source: \(source)") }
        if let notesValue = initialDraft.notes { draftNotes.append(notesValue) }
        let combinedDraftNotes = draftNotes.joined(separator: "\n")

        if !combinedDraftNotes.isEmpty {
            if notes.isEmpty {
                notes = truncatedNotes(from: combinedDraftNotes)
            } else {
                let combined = notes + "\n" + combinedDraftNotes
                notes = truncatedNotes(from: combined)
            }
        }

        warnings = initialDraft.parseWarnings

        if mode == .voice && autoStartVoice {
            transcriber.startRecording()
        }
    }

    private func applyUITestOverridesIfNeeded() {
        guard !didApplyUITestOverrides else { return }
        guard mode == .manual else { return }
        guard ProcessInfo.processInfo.arguments.contains("UITests") else { return }

        if let override = Self.nextUITestTimeOverride() {
            timestamp = override
        }
        didApplyUITestOverrides = true
    }

    private static func nextUITestTimeOverride() -> Date? {
        guard uiTestTimeIndex < uiTestTimeOverrides.count else { return nil }
        let override = uiTestTimeOverrides[uiTestTimeIndex]
        uiTestTimeIndex += 1
        return override
    }

    private func truncatedNotes(from text: String) -> String {
        if text.count <= 200 { return text }
        let prefix = text.prefix(200)
        return String(prefix)
    }

    private var limitedNotesBinding: Binding<String> {
        Binding<String>(
            get: { notes },
            set: { newValue in
                notes = String(newValue.prefix(200))
            }
        )
    }
}

#Preview {
    NavigationStack {
        NewEventView(mode: .voice, initialDraft: nil, autoStartVoice: false) { _ in }
    }
}
