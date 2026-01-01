import Foundation

struct ParsedEventDraft: Equatable, Hashable {
    var type: EventType?
    var subtype: String?
    var timestamp: Date?
    var source: String?
    var notes: String?
    var rawText: String
    var confidence: Double?
    var parseWarnings: [String]
}

struct EventTranscriptParser {
    func parse(_ transcript: String, now: Date = .now) -> ParsedEventDraft {
        let lowered = transcript.lowercased()
        var warnings: [String] = []

        let type = detectType(in: lowered)
        if type == nil {
            warnings.append("Couldn't detect event type.")
        }

        let subtype = detectSubtype(in: lowered)
        let timestamp = detectTime(in: lowered, now: now)

        let notes = extractNotes(original: transcript)

        return ParsedEventDraft(
            type: type,
            subtype: subtype,
            timestamp: timestamp ?? now,
            notes: notes,
            rawText: transcript,
            confidence: nil,
            parseWarnings: warnings
        )
    }

    private func detectType(in text: String) -> EventType? {
        let candidates: [(EventType, [String])] = [
            (
                .dystonia,
                [
                    "dystonia", "dystonic", "event type dystonia", "event dystonia",
                    "distonia", "dastonia", "justonia", "dystonya"
                ]
            ),
            (
                .dyskinesia,
                [
                    "dyskinesia", "dyskinesia episode", "event type dyskinesia", "event dyskinesia",
                    "diskinesia", "diskenesia", "diskinesya", "dyskinesya", "dis kinesia"
                ]
            ),
            (
                .wearingOff,
                [
                    "wearing off", "wearing-off", "off period", "event off", "event wearing", "event type off", "event type wearing off"
                ]
            ),
            (
                .tremor,
                ["tremor", "trimmer", "tremour", "shaking", "shaky", "shake", "shakes", "shaken"]
            ),
            (
                .bradykinesia,
                ["bradykinesia", "bradikinesia", "slow movement", "slow movements", "slowdown", "slowness", "slow"]
            ),
            (
                .rigidity,
                ["rigidity", "rigid", "stiffness", "stiffnes", "stiff", "spasm", "spasms", "spastic"]
            ),
            (
                .batteryCharge,
                ["battery charge", "battery charged", "charge battery", "charging battery", "battery level", "battery percent", "battery percentage"]
            ),
            (
                .stimulationChange,
                ["stimulation change", "stim change", "stimulation adjusted", "stim adjusted", "stimulation adjustment", "stim adjustment"]
            ),
            (
                .physicalActivity,
                ["physical activity", "activity", "exercise", "workout", "walking", "run", "running", "gym"]
            ),
            (
                .feelsGood,
                ["feels good", "feel good", "feeling good", "feeling ok", "better now"]
            )
        ]

        let matches = candidates.compactMap { eventType, keywords in
            keywords.contains { text.contains($0) } ? eventType : nil
        }

        return matches.first
    }

    private func detectSubtype(in text: String) -> String? {
        let patterns = [
            "sub type is\\s+([^,]*)",
            "subtype\\s+([^,]*)",
            "sub type\\s+([^,]*)",
            "detail is\\s+([^,]*)",
            "details is\\s+([^,]*)",
            "detail\\s+([^,]*)",
            "details\\s+([^,]*)"
        ]

        for pattern in patterns {
            if let match = text.range(of: pattern, options: .regularExpression) {
                let value = text[match]
                    .replacingOccurrences(of: "sub type is", with: "")
                    .replacingOccurrences(of: "subtype", with: "")
                    .replacingOccurrences(of: "sub type", with: "")
                    .replacingOccurrences(of: "detail is", with: "")
                    .replacingOccurrences(of: "details is", with: "")
                    .replacingOccurrences(of: "detail", with: "")
                    .replacingOccurrences(of: "details", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmed = trimSubtypeSuffixes(in: value)
                return trimmed.capitalized
            }
        }

        return nil
    }

    private func trimSubtypeSuffixes(in value: String) -> String {
        let separators = [" at ", " after ", " before ", " on "]
        var output = value
        for separator in separators {
            if let range = output.range(of: separator) {
                output = String(output[..<range.lowerBound])
            }
        }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func detectTime(in text: String, now: Date) -> Date? {
        let colonPattern = "at\\s+(\\d{1,2})[:](\\d{2})"
        if let regex = try? NSRegularExpression(pattern: colonPattern, options: .caseInsensitive) {
            let range = NSRange(location: 0, length: text.utf16.count)
            if let match = regex.firstMatch(in: text, options: [], range: range) {
                let hourString = substring(text, from: match.range(at: 1))
                let minuteString = substring(text, from: match.range(at: 2))
                return makeDate(now: now, hourString: hourString, minuteString: minuteString)
            }
        }

        let spacedPattern = "at\\s+(\\d{1,2})\\s+(\\d{2})"
        if let regex = try? NSRegularExpression(pattern: spacedPattern, options: .caseInsensitive) {
            let range = NSRange(location: 0, length: text.utf16.count)
            if let match = regex.firstMatch(in: text, options: [], range: range) {
                let hourString = substring(text, from: match.range(at: 1))
                let minuteString = substring(text, from: match.range(at: 2))
                return makeDate(now: now, hourString: hourString, minuteString: minuteString)
            }
        }

        return nil
    }

    private func makeDate(now: Date, hourString: String, minuteString: String) -> Date? {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: now)
        components.hour = Int(hourString)
        components.minute = Int(minuteString)
        return Calendar.current.date(from: components)
    }

    private func extractNotes(original: String) -> String? {
        let trimmed = original.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func substring(_ text: String, from range: NSRange) -> String {
        guard let swiftRange = Range(range, in: text) else { return "" }
        return String(text[swiftRange])
    }
}
