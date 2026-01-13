import UIKit
import Vision
import XCTest

final class DBSEventTemplateUITests: XCTestCase {
    func testEventRecordedCopyContainsTimeAndMessage() throws {
        guard let image = loadImage(named: "event_recorded_test1") else {
            XCTFail("Missing test image in UI test bundle")
            return
        }
        guard let cgImage = normalizedCGImage(from: image) else {
            XCTFail("Test image has no CGImage")
            return
        }

        let fullText = try recognizeText(in: cgImage, orientation: cgOrientation(for: image.imageOrientation), region: nil)
        let timeText = try recognizeText(
            in: cgImage,
            orientation: cgOrientation(for: image.imageOrientation),
            region: visionRegion(from: CGRect(x: 0.0, y: 0.0, width: 0.35, height: 0.15))
        )

        XCTAssertTrue(fullText.lowercased().contains("event recorded"), "OCR should include 'event recorded'.")
        XCTAssertTrue(fullText.lowercased().contains("ok"), "OCR should include 'ok'.")

        let meaningful = extractBetweenMarkers(text: fullText, start: "event recorded", end: "ok")
        XCTAssertFalse(meaningful.isEmpty, "Expected meaningful text between 'event recorded' and 'ok'.")

        let timeRegex = try NSRegularExpression(pattern: "(\\d{1,2})[:](\\d{2})", options: [])
        let timeRange = NSRange(location: 0, length: timeText.utf16.count)
        XCTAssertNotNil(timeRegex.firstMatch(in: timeText, options: [], range: timeRange), "Expected time in top-left text.")
    }

    private func loadImage(named name: String) -> UIImage? {
        guard let url = Bundle(for: type(of: self)).url(forResource: name, withExtension: "png") else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }

    private func normalizedCGImage(from image: UIImage) -> CGImage? {
        guard image.imageOrientation != .up else { return image.cgImage }
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        let renderer = UIGraphicsImageRenderer(size: image.size, format: format)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
        return rendered.cgImage
    }

    private func recognizeText(in cgImage: CGImage, orientation: CGImagePropertyOrientation, region: CGRect?) throws -> String {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        if let region {
            request.regionOfInterest = region
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
        try handler.perform([request])

        let observations = request.results ?? []
        let strings = observations.compactMap { $0.topCandidates(1).first?.string }
        return strings.joined(separator: " \n ")
    }

    private func extractBetweenMarkers(text: String, start: String, end: String) -> String {
        let lower = text.lowercased()
        guard let startRange = lower.range(of: start) else { return "" }
        let searchStart = startRange.upperBound
        let searchRange = searchStart..<lower.endIndex
        let endRange = lower.range(of: end, options: [], range: searchRange)
        let endIndex = endRange?.lowerBound ?? lower.endIndex
        let segment = text[searchStart..<endIndex]
        return segment.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func visionRegion(from normalizedRect: CGRect) -> CGRect {
        CGRect(
            x: normalizedRect.minX,
            y: 1 - normalizedRect.maxY,
            width: normalizedRect.width,
            height: normalizedRect.height
        )
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
