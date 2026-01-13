import CoreImage
import Foundation
import UIKit
import Vision

struct DBSEventTemplateRegions {
    let redStatusBar: CGRect
    let greenEventBox: CGRect
}

struct DBSEventTemplateLayout {
    static let matchAspect: CGFloat = 3.0 / 4.0
    static let templateScale: CGFloat = 0.72
    static let templateYOffset: CGFloat = 0.04
}

final class DBSEventTemplateStore {
    static let shared: DBSEventTemplateStore? = DBSEventTemplateStore(bundle: .main)
    static let matchThreshold: Float = 0.6
    private static let fallbackThreshold: Float = 0.3
    private static let matchCanvasSize = CGSize(width: 768, height: 1024)
    private static let fallbackSize = CGSize(width: 48, height: 64)

    let featurePrint: VNFeaturePrintObservation
    let regions: DBSEventTemplateRegions
    private let templatePlacement: CGRect
    private let fallbackTemplate: [UInt8]
    private let ciContext = CIContext()

    static func makeStore(templateImage: UIImage) -> DBSEventTemplateStore? {
        DBSEventTemplateStore(templateImage: templateImage)
    }

    private convenience init?(bundle: Bundle) {
        guard let image = UIImage(named: "event_recorded_template_alpha", in: bundle, compatibleWith: nil) else {
            return nil
        }
        self.init(templateImage: image)
    }

    private init?(templateImage: UIImage) {
        guard let cgImage = templateImage.cgImage else { return nil }
        let templateSize = CGSize(width: cgImage.width, height: cgImage.height)
        let placement = Self.templatePlacementRect(for: templateSize)
        guard let canvasImage = Self.renderTemplateCanvas(from: cgImage, placement: placement) else { return nil }
        guard let featurePrint = try? Self.makeFeaturePrint(from: canvasImage) else { return nil }
        guard let fallbackTemplate = Self.fallbackVector(from: canvasImage) else { return nil }

        self.featurePrint = featurePrint
        self.fallbackTemplate = fallbackTemplate
        self.templatePlacement = placement
        self.regions = Self.detectRegions(in: cgImage) ?? Self.defaultRegions(for: templateSize)
    }

    func matches(cgImage: CGImage, orientation: CGImagePropertyOrientation) throws -> Bool {
        guard let oriented = orientedCGImage(from: cgImage, orientation: orientation),
              let normalized = normalizeForMatching(cgImage: oriented) else {
            return false
        }

        if let visionMatch = try? visionMatch(cgImage: normalized), visionMatch {
            return true
        }
        if fallbackMatch(cgImage: normalized) {
            return true
        }
        return ocrMatch(cgImage: normalized)
    }

    func matches(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) throws -> Bool {
        guard let oriented = orientedCGImage(from: pixelBuffer, orientation: orientation),
              let normalized = normalizeForMatching(cgImage: oriented) else {
            return false
        }

        if let visionMatch = try? visionMatch(cgImage: normalized), visionMatch {
            return true
        }
        if fallbackMatch(cgImage: normalized) {
            return true
        }
        return ocrMatch(cgImage: normalized)
    }

    func visionRegion(for templateRegion: CGRect, inputSize: CGSize) -> CGRect {
        let normalized = normalizedRegion(for: templateRegion, inputSize: inputSize)
        return CGRect(
            x: normalized.minX,
            y: 1 - normalized.maxY,
            width: normalized.width,
            height: normalized.height
        )
    }

    private func visionMatch(cgImage: CGImage) throws -> Bool {
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])
        guard let observation = request.results?.first as? VNFeaturePrintObservation else {
            return false
        }

        var distance: Float = 0
        try featurePrint.computeDistance(&distance, to: observation)
        return distance <= Self.matchThreshold
    }

    private static func makeFeaturePrint(from cgImage: CGImage) throws -> VNFeaturePrintObservation {
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        try handler.perform([request])
        guard let observation = request.results?.first as? VNFeaturePrintObservation else {
            throw NSError(domain: "DBSEventTemplateStore", code: 1)
        }
        return observation
    }

    private func fallbackMatch(cgImage: CGImage) -> Bool {
        guard let vector = Self.fallbackVector(from: cgImage) else { return false }
        let count = min(vector.count, fallbackTemplate.count)
        guard count > 0 else { return false }

        var sum: Int = 0
        for index in 0..<count {
            sum += abs(Int(vector[index]) - Int(fallbackTemplate[index]))
        }

        let average = Float(sum) / Float(count) / 255.0
        return average <= Self.fallbackThreshold
    }

    private func ocrMatch(cgImage: CGImage) -> Bool {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false
        request.regionOfInterest = visionRegion(from: CGRect(x: 0.1, y: 0.2, width: 0.8, height: 0.6))

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        guard (try? handler.perform([request])) != nil else {
            return false
        }

        let strings = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
        let text = strings.joined(separator: " ").lowercased()
        return text.contains("event") && (text.contains("recorded") || text.contains("ok"))
    }

    private static func detectRegions(in cgImage: CGImage) -> DBSEventTemplateRegions? {
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        var data = [UInt8](repeating: 0, count: height * bytesPerRow)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: &data,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var redMinX = Int.max
        var redMinY = Int.max
        var redMaxX = 0
        var redMaxY = 0
        var greenMinX = Int.max
        var greenMinY = Int.max
        var greenMaxX = 0
        var greenMaxY = 0
        var redFound = false
        var greenFound = false

        for y in 0..<height {
            let rowOffset = y * bytesPerRow
            for x in 0..<width {
                let offset = rowOffset + x * bytesPerPixel
                let r = data[offset]
                let g = data[offset + 1]
                let b = data[offset + 2]
                let a = data[offset + 3]

                if a < 40 { continue }

                if r > 180 && g < 110 && b < 110 {
                    redFound = true
                    redMinX = min(redMinX, x)
                    redMinY = min(redMinY, y)
                    redMaxX = max(redMaxX, x)
                    redMaxY = max(redMaxY, y)
                    continue
                }

                if g > 150 && r < 150 && b < 150 {
                    greenFound = true
                    greenMinX = min(greenMinX, x)
                    greenMinY = min(greenMinY, y)
                    greenMaxX = max(greenMaxX, x)
                    greenMaxY = max(greenMaxY, y)
                }
            }
        }

        guard redFound, greenFound else { return nil }

        let redRect = CGRect(
            x: redMinX,
            y: redMinY,
            width: max(1, redMaxX - redMinX + 1),
            height: max(1, redMaxY - redMinY + 1)
        )
        let greenRect = CGRect(
            x: greenMinX,
            y: greenMinY,
            width: max(1, greenMaxX - greenMinX + 1),
            height: max(1, greenMaxY - greenMinY + 1)
        )

        return DBSEventTemplateRegions(
            redStatusBar: normalize(rect: redRect, width: width, height: height),
            greenEventBox: normalize(rect: greenRect, width: width, height: height)
        )
    }

    private static func normalize(rect: CGRect, width: Int, height: Int) -> CGRect {
        CGRect(
            x: rect.minX / CGFloat(width),
            y: rect.minY / CGFloat(height),
            width: rect.width / CGFloat(width),
            height: rect.height / CGFloat(height)
        )
    }

    private static func defaultRegions(for size: CGSize) -> DBSEventTemplateRegions {
        DBSEventTemplateRegions(
            redStatusBar: CGRect(x: 0.06, y: 0.02, width: 0.88, height: 0.08),
            greenEventBox: CGRect(x: 0.08, y: 0.36, width: 0.84, height: 0.2)
        )
    }

    private static func templatePlacementRect(for templateSize: CGSize) -> CGRect {
        let canvasSize = matchCanvasSize
        let baseScale = min(canvasSize.width / templateSize.width, canvasSize.height / templateSize.height)
        let scale = baseScale * DBSEventTemplateLayout.templateScale
        let scaledSize = CGSize(width: templateSize.width * scale, height: templateSize.height * scale)
        let origin = CGPoint(
            x: (canvasSize.width - scaledSize.width) / 2.0,
            y: (canvasSize.height - scaledSize.height) / 2.0 + (DBSEventTemplateLayout.templateYOffset * canvasSize.height)
        )
        return CGRect(
            x: origin.x / canvasSize.width,
            y: origin.y / canvasSize.height,
            width: scaledSize.width / canvasSize.width,
            height: scaledSize.height / canvasSize.height
        )
    }

    private static func renderTemplateCanvas(from cgImage: CGImage, placement: CGRect) -> CGImage? {
        let canvasSize = matchCanvasSize
        let width = Int(canvasSize.width)
        let height = Int(canvasSize.height)
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }

        context.setFillColor(UIColor.black.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: canvasSize.width, height: canvasSize.height))

        let drawRect = CGRect(
            x: placement.minX * canvasSize.width,
            y: placement.minY * canvasSize.height,
            width: placement.width * canvasSize.width,
            height: placement.height * canvasSize.height
        )
        context.draw(cgImage, in: drawRect)
        return context.makeImage()
    }

    private func normalizeForMatching(cgImage: CGImage) -> CGImage? {
        let inputSize = CGSize(width: cgImage.width, height: cgImage.height)
        let cropRect = cropRect(for: inputSize)
        guard let cropped = cgImage.cropping(to: cropRect) else { return nil }
        return Self.resize(cgImage: cropped, size: Self.matchCanvasSize)
    }

    private func normalizedRegion(for templateRegion: CGRect, inputSize: CGSize) -> CGRect {
        let cropRect = cropRect(for: inputSize)
        let placement = templatePlacement

        let templateRect = CGRect(
            x: cropRect.minX + (placement.minX + templateRegion.minX * placement.width) * cropRect.width,
            y: cropRect.minY + (placement.minY + templateRegion.minY * placement.height) * cropRect.height,
            width: templateRegion.width * placement.width * cropRect.width,
            height: templateRegion.height * placement.height * cropRect.height
        )

        return CGRect(
            x: templateRect.minX / inputSize.width,
            y: templateRect.minY / inputSize.height,
            width: templateRect.width / inputSize.width,
            height: templateRect.height / inputSize.height
        )
    }

    private func cropRect(for inputSize: CGSize) -> CGRect {
        let inputAspect = inputSize.width / inputSize.height
        if inputAspect > DBSEventTemplateLayout.matchAspect {
            let targetWidth = inputSize.height * DBSEventTemplateLayout.matchAspect
            let originX = (inputSize.width - targetWidth) / 2.0
            return CGRect(x: originX, y: 0, width: targetWidth, height: inputSize.height)
        } else {
            let targetHeight = inputSize.width / DBSEventTemplateLayout.matchAspect
            let originY = (inputSize.height - targetHeight) / 2.0
            return CGRect(x: 0, y: originY, width: inputSize.width, height: targetHeight)
        }
    }

    private static func resize(cgImage: CGImage, size: CGSize) -> CGImage? {
        let width = Int(size.width)
        let height = Int(size.height)
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }

        context.interpolationQuality = .high
        context.draw(cgImage, in: CGRect(origin: .zero, size: size))
        return context.makeImage()
    }

    private static func fallbackVector(from cgImage: CGImage) -> [UInt8]? {
        guard let resized = resize(cgImage: cgImage, size: fallbackSize) else { return nil }
        let width = Int(fallbackSize.width)
        let height = Int(fallbackSize.height)
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        var data = [UInt8](repeating: 0, count: height * bytesPerRow)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: &data,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }

        context.draw(resized, in: CGRect(origin: .zero, size: fallbackSize))

        var grayscale = [UInt8]()
        grayscale.reserveCapacity(width * height)
        for index in stride(from: 0, to: data.count, by: 4) {
            let r = Float(data[index])
            let g = Float(data[index + 1])
            let b = Float(data[index + 2])
            let value = UInt8(min(255, (0.299 * r + 0.587 * g + 0.114 * b)))
            grayscale.append(value)
        }
        return grayscale
    }

    private func orientedCGImage(from cgImage: CGImage, orientation: CGImagePropertyOrientation) -> CGImage? {
        guard orientation != .up else { return cgImage }
        let ciImage = CIImage(cgImage: cgImage).oriented(orientation)
        return ciContext.createCGImage(ciImage, from: ciImage.extent)
    }

    private func orientedCGImage(from pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) -> CGImage? {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer).oriented(orientation)
        return ciContext.createCGImage(ciImage, from: ciImage.extent)
    }

    private func visionRegion(from normalizedRect: CGRect) -> CGRect {
        CGRect(
            x: normalizedRect.minX,
            y: 1 - normalizedRect.maxY,
            width: normalizedRect.width,
            height: normalizedRect.height
        )
    }
}
