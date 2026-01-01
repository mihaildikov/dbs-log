import Foundation
import Vision
import UIKit

struct PhotoEventAnalyzer {
    enum AnalyzerError: Error {
        case noText
        case invalidImage
    }

    func analyze(image: UIImage, now: Date = .now) async throws -> ParsedEventDraft {
        guard let cgImage = image.cgImage else { throw AnalyzerError.invalidImage }

        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: cgOrientation(for: image.imageOrientation), options: [:])
        try handler.perform([request])

        let observations = request.results ?? []
        let strings = observations.compactMap { $0.topCandidates(1).first?.string }
        let combinedText = strings.joined(separator: " \n ")

        guard !combinedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AnalyzerError.noText
        }

        let lowered = combinedText.lowercased()
        let type = detectType(in: lowered)
        let timestamp = now
        let source = detectSource(in: lowered)
        let notes = extractNotes(from: combinedText)

        return ParsedEventDraft(
            type: type,
            subtype: nil,
            timestamp: timestamp,
            source: source,
            notes: notes,
            rawText: combinedText,
            confidence: nil,
            parseWarnings: []
        )
    }

    private func detectType(in text: String) -> EventType? {
        let keywords: [(EventType, [String])] = [
            (.dystonia, ["dystonia", "dystonic", "distonia", "dastonia"]),
            (.dyskinesia, ["dyskinesia", "diskinesia", "dys kinesia"]),
            (.wearingOff, ["wearing off", "wearing-off", "off period", "event off", "wearing off recorded", "wearing-off recorded"]),
            (.tremor, ["tremor", "trimmer", "tremour", "shaking", "shaky", "shake", "shakes", "shaken"]),
            (.bradykinesia, ["bradykinesia", "bradikinesia", "slow movement", "slow movements", "slowdown", "slowness", "slow"]),
            (.rigidity, ["rigidity", "rigid", "stiffness", "stiffnes", "stiff", "spasm", "spasms", "spastic"]),
            (.batteryCharge, ["battery charge", "battery charged", "charge battery", "charging battery", "battery level", "battery percent", "battery percentage"]),
            (.feelsGood, ["feels good", "feel good", "feeling good", "better now", "feeling ok"])
        ]

        var recordedCandidate: (EventType, Int)?
        var firstCandidate: (EventType, Int)?

        for (type, words) in keywords {
            for word in words {
                guard let range = text.range(of: word) else { continue }
                let index = text.distance(from: text.startIndex, to: range.lowerBound)

                let recordedMatch = text.contains("\(word) recorded") || text.contains("recorded \(word)") || word.contains("recorded")

                if recordedMatch {
                    if let current = recordedCandidate {
                        if index < current.1 { recordedCandidate = (type, index) }
                    } else {
                        recordedCandidate = (type, index)
                    }
                }

                if let current = firstCandidate {
                    if index < current.1 { firstCandidate = (type, index) }
                } else {
                    firstCandidate = (type, index)
                }
            }
        }

        return recordedCandidate?.0 ?? firstCandidate?.0
    }

    private func detectTime(in text: String, now: Date) -> Date? {
        let colonPattern = "(\\d{1,2})[:](\\d{2})"
        if let regex = try? NSRegularExpression(pattern: colonPattern, options: .caseInsensitive) {
            let range = NSRange(location: 0, length: text.utf16.count)
            if let match = regex.firstMatch(in: text, options: [], range: range) {
                let hourString = substring(text, from: match.range(at: 1))
                let minuteString = substring(text, from: match.range(at: 2))
                return makeDate(now: now, hourString: hourString, minuteString: minuteString)
            }
        }

        let spacedPattern = "(\\d{1,2})\\s+(\\d{2})"
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

    private func detectSource(in text: String) -> String? {
        var tokens: [String] = []
        let sources = ["samsung", "medtronic", "percept", "watch"]
        for keyword in sources where text.contains(keyword) {
            tokens.append(keyword.capitalized)
        }
        return tokens.isEmpty ? nil : tokens.joined(separator: " ")
    }

    private func extractNotes(from text: String) -> String? {
        let lower = text.lowercased()
        guard let startRange = lower.range(of: "event recorded") else {
            return nil
        }

        let searchStart = startRange.upperBound
        let searchRange = searchStart..<lower.endIndex
        let endRange = lower.range(of: "ok", options: [], range: searchRange)

        let endIndex = endRange?.lowerBound ?? lower.endIndex
        let segment = text[searchStart..<endIndex]
        let cleaned = segment.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    private func makeDate(now: Date, hourString: String, minuteString: String) -> Date? {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: now)
        components.hour = Int(hourString)
        components.minute = Int(minuteString)
        return Calendar.current.date(from: components)
    }

    private func substring(_ text: String, from range: NSRange) -> String {
        guard let swiftRange = Range(range, in: text) else { return "" }
        return String(text[swiftRange])
    }

    private func cgOrientation(for orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
