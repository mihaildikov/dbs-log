import SwiftUI

struct ShareEventsView: View {
    let events: [Event]

    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    private var tableDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }

    private func isRecorded(_ event: Event) -> Bool {
        guard let notes = event.notes?.lowercased() else { return false }
        return notes.contains("recorded")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            List {
                HStack {
                    Text("Date")
                        .font(.headline)
                    Spacer()
                    Text("Time")
                        .font(.headline)
                    Spacer()
                    Text("Event")
                        .font(.headline)
                    Spacer()
                    Text("Details")
                        .font(.headline)
                }
                .padding(.vertical, 4)

                ForEach(events) { event in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(dateFormatter.string(from: event.timestamp))
                            Spacer()
                            Text(timeFormatter.string(from: event.timestamp))
                            Spacer()
                            Text(event.type.displayName)
                            Spacer()
                            Text(event.subtype ?? "-")
                        }
                        if let notes = event.notes, !notes.isEmpty {
                            Text(notes)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .listStyle(.plain)

            ShareLink(item: pdfURL(for: events), preview: SharePreview("DBS Log")) {
                Label("Share", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .navigationTitle("Share")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func pdfURL(for events: [Event]) -> URL {
        let sortedEvents = events.sorted { $0.timestamp < $1.timestamp }
        let recordedEvents = sortedEvents.filter { isRecorded($0) }
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        let fileFormatter = ISO8601DateFormatter()
        fileFormatter.formatOptions = [.withInternetDateTime]
        let timestampString = fileFormatter.string(from: .now).replacingOccurrences(of: ":", with: "-")
        let filename = "dbs_export_\(timestampString).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.alignment = .left

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 20)
        ]
        let sectionAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 14)
        ]
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 11)
        ]
        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 11),
            .paragraphStyle: paragraph
        ]
        let smallAttributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 10),
            .paragraphStyle: paragraph
        ]

        func drawWrappedText(_ text: String, x: CGFloat, y: CGFloat, width: CGFloat, attributes: [NSAttributedString.Key: Any]) -> CGFloat {
            let rect = CGRect(x: x, y: y, width: width, height: .greatestFiniteMagnitude)
            let bounding = (text as NSString).boundingRect(with: rect.size, options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attributes, context: nil)
            let drawRect = CGRect(x: x, y: y, width: width, height: ceil(bounding.height))
            (text as NSString).draw(in: drawRect, withAttributes: attributes)
            return ceil(bounding.height)
        }

        func patientState(for event: Event) -> String {
            let base: String
            switch event.type {
            case .feelsGood:
                base = "Feels good"
            case .wearingOff:
                base = "Wearing off"
            case .dyskinesia:
                base = "Dyskinesia"
            case .dystonia:
                base = "Dystonia"
            case .tremor:
                base = "Tremor"
            case .bradykinesia:
                base = "Bradykinesia"
            case .rigidity:
                base = "Rigidity"
            case .batteryCharge:
                base = "Battery charge"
            case .stimulationChange:
                base = "Stimulation change"
            case .physicalActivity:
                base = "Physical activity"
            case .medication:
                base = "Medication"
            }
            if let subtype = event.subtype, !subtype.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "\(base) - \(subtype)"
            }
            return base
        }

        func medicationContext(for event: Event) -> String {
            let priorMeds = sortedEvents.filter { $0.type == .medication && $0.timestamp <= event.timestamp }
            guard let lastMed = priorMeds.last else { return "-" }
            let detail = lastMed.subtype ?? lastMed.notes ?? "Medication"
            let medTime = timeFormatter.string(from: lastMed.timestamp)
            return "\(detail) @ \(medTime)"
        }

        func notesWithoutRecorded(_ notes: String) -> String {
            let cleaned = notes.replacingOccurrences(of: "(?i)recorded", with: "", options: .regularExpression)
            let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "-" : trimmed
        }

        func programmerSummaryText() -> String {
            guard !recordedEvents.isEmpty else {
                return "No Percept-linked events were found. Review the context timeline below."
            }
            let times = recordedEvents.map { timeFormatter.string(from: $0.timestamp) }
            let types = Array(Set(recordedEvents.map { $0.type.displayName })).sorted()
            var sentences: [String] = []
            sentences.append("Percept-linked events: \(recordedEvents.count) at \(times.joined(separator: ", ")).")
            sentences.append("Recorded types: \(types.joined(separator: ", ")).")

            let feelsGoodTimes = recordedEvents.filter { $0.type == .feelsGood }.map { timeFormatter.string(from: $0.timestamp) }
            if !feelsGoodTimes.isEmpty {
                sentences.append("Feels Good recordings at \(feelsGoodTimes.joined(separator: ", ")).")
            }
            let wearingOffTimes = recordedEvents.filter { $0.type == .wearingOff }.map { timeFormatter.string(from: $0.timestamp) }
            if !wearingOffTimes.isEmpty {
                sentences.append("Wearing OFF recordings at \(wearingOffTimes.joined(separator: ", ")).")
            }
            sentences.append("Review these scans first; use the context timeline only as needed.")
            return sentences.joined(separator: " ")
        }

        do {
            try renderer.writePDF(to: url) { context in
                context.beginPage()

                let pageWidth: CGFloat = 612
                let leftMargin: CGFloat = 20
                let contentWidth: CGFloat = pageWidth - (leftMargin * 2)
                var y: CGFloat = 20

                "DBS Log Programmer Summary".draw(at: CGPoint(x: leftMargin, y: y), withAttributes: titleAttributes)
                y += 26
                let generatedLine = "Generated: \(dateFormatter.string(from: .now))"
                y += drawWrappedText(generatedLine, x: leftMargin, y: y, width: contentWidth, attributes: smallAttributes) + 8

                "Percept-Linked Events Summary".draw(at: CGPoint(x: leftMargin, y: y), withAttributes: sectionAttributes)
                y += 18

                if recordedEvents.isEmpty {
                    y += drawWrappedText("No events marked as recorded.", x: leftMargin, y: y, width: contentWidth, attributes: bodyAttributes) + 12
                } else {
                    let columnWidths: [CGFloat] = [55, 130, 120, 120, contentWidth - 425]
                    let headers = ["Time", "Percept Label", "Patient State", "Med Context", "Interpretation"]

                    func drawTableRow(_ values: [String], yPos: inout CGFloat, attributes: [NSAttributedString.Key: Any]) {
                        var x = leftMargin
                        var maxHeight: CGFloat = 0

                        for (index, value) in values.enumerated() {
                            let width = columnWidths[index]
                            let height = (value as NSString).boundingRect(
                                with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                options: [.usesLineFragmentOrigin, .usesFontLeading],
                                attributes: attributes,
                                context: nil
                            ).height
                            maxHeight = max(maxHeight, ceil(height))
                            x += width
                        }

                        x = leftMargin
                        for (index, value) in values.enumerated() {
                            let width = columnWidths[index]
                            let rect = CGRect(x: x, y: yPos, width: width, height: maxHeight)
                            (value as NSString).draw(in: rect, withAttributes: attributes)
                            x += width
                        }
                        yPos += maxHeight + 6
                    }

                    drawTableRow(headers, yPos: &y, attributes: headerAttributes)

                    for event in recordedEvents {
                        if y > 700 {
                            context.beginPage()
                            y = 20
                            "Percept-Linked Events Summary (continued)".draw(at: CGPoint(x: leftMargin, y: y), withAttributes: sectionAttributes)
                            y += 18
                            drawTableRow(headers, yPos: &y, attributes: headerAttributes)
                        }
                        let time = timeFormatter.string(from: event.timestamp)
                        let label = "\(event.type.displayName) (recorded)"
                        let state = patientState(for: event)
                        let medContext = medicationContext(for: event)
                        let interpretation = notesWithoutRecorded(event.notes ?? "")
                        drawTableRow([time, label, state, medContext, interpretation], yPos: &y, attributes: bodyAttributes)
                    }
                }

                if y > 660 {
                    context.beginPage()
                    y = 20
                }
                "Programmer Summary".draw(at: CGPoint(x: leftMargin, y: y), withAttributes: sectionAttributes)
                y += 16
                y += drawWrappedText(programmerSummaryText(), x: leftMargin, y: y, width: contentWidth, attributes: bodyAttributes) + 12

                context.beginPage()
                y = 20
                "Context Timeline".draw(at: CGPoint(x: leftMargin, y: y), withAttributes: sectionAttributes)
                y += 16

                var currentDate: Date?
                let calendar = Calendar.current
                for event in sortedEvents {
                    let eventDay = calendar.startOfDay(for: event.timestamp)
                    if currentDate != eventDay {
                        if y > 720 {
                            context.beginPage()
                            y = 20
                            "Context Timeline (continued)".draw(at: CGPoint(x: leftMargin, y: y), withAttributes: sectionAttributes)
                            y += 16
                        }
                        let dateHeader = dateFormatter.string(from: event.timestamp)
                        y += drawWrappedText(dateHeader, x: leftMargin, y: y, width: contentWidth, attributes: headerAttributes) + 6
                        currentDate = eventDay
                    }

                    let marker = isRecorded(event) ? "[REC]" : "[CTX]"
                    let time = timeFormatter.string(from: event.timestamp)
                    var line = "\(time) \(marker) \(event.type.displayName)"
                    if let subtype = event.subtype, !subtype.isEmpty {
                        line += " - \(subtype)"
                    }
                    if let notes = event.notes, !notes.isEmpty {
                        let cleaned = notesWithoutRecorded(notes)
                        if cleaned != "-" {
                            line += " (\(cleaned))"
                        }
                    }

                    if y > 740 {
                        context.beginPage()
                        y = 20
                        "Context Timeline (continued)".draw(at: CGPoint(x: leftMargin, y: y), withAttributes: sectionAttributes)
                        y += 16
                    }
                    y += drawWrappedText(line, x: leftMargin, y: y, width: contentWidth, attributes: bodyAttributes) + 6
                }
            }
        } catch {
            return url
        }

        return url
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
