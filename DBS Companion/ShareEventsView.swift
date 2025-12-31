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

            ShareLink(item: pdfURL(for: events), preview: SharePreview("DBS Companion")) {
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
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        let fileFormatter = ISO8601DateFormatter()
        fileFormatter.formatOptions = [.withInternetDateTime]
        let timestampString = fileFormatter.string(from: .now).replacingOccurrences(of: ":", with: "-")
        let filename = "dbs_export_\(timestampString).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        paragraph.alignment = .left

        do {
            try renderer.writePDF(to: url) { context in
                context.beginPage()

                var y: CGFloat = 20

                let title = "DBS Companion Export"
                let titleAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 20)
                ]
                title.draw(at: CGPoint(x: 20, y: y), withAttributes: titleAttributes)
                y += 30

                let headerAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 12)
                ]
                let bodyAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 12),
                    .paragraphStyle: paragraph
                ]

                for event in sortedEvents {
                    if y > 740 {
                        context.beginPage()
                        y = 20
                    }

                    let date = dateFormatter.string(from: event.timestamp)
                    let time = timeFormatter.string(from: event.timestamp)
                    let details = event.subtype ?? ""
                    let notes = event.notes ?? ""

                    let header = "Date: \(date)    Time: \(time)"
                    header.draw(at: CGPoint(x: 20, y: y), withAttributes: headerAttributes)
                    y += 18

                    let typeLine = "Type: \(event.type.displayName)"
                    typeLine.draw(at: CGPoint(x: 20, y: y), withAttributes: bodyAttributes)
                    y += 16

                    if !details.isEmpty {
                        let detailsLine = "Details: \(details)"
                        detailsLine.draw(at: CGPoint(x: 20, y: y), withAttributes: bodyAttributes)
                        y += 16
                    }

                    if !notes.isEmpty {
                        let notesString = "Notes: \(notes)"
                        let notesRect = CGRect(x: 20, y: y, width: 572, height: 200)
                        notesString.draw(in: notesRect, withAttributes: bodyAttributes)
                        y += 60
                    }

                    y += 14
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
