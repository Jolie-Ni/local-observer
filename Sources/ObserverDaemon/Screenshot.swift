import CoreGraphics
import Foundation
import ImageIO
import ObserverCore
import UniformTypeIdentifiers

enum Screenshot {
    /// Capture the main display.
    /// TODO: migrate to ScreenCaptureKit. CGDisplayCreateImage is deprecated
    /// on macOS 14+ but still functional; ScreenCaptureKit is the future-proof path.
    static func capture() -> CGImage? {
        let displayID = CGMainDisplayID()
        guard let raw = CGDisplayCreateImage(displayID) else { return nil }
        return downscale(raw, maxDimension: Config.screenshotMaxDimension) ?? raw
    }

    /// Save as JPEG. Returns the file URL on success.
    static func save(_ image: CGImage, dir: URL) -> URL? {
        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let filename = "\(stamp).jpg"
        let url = dir.appendingPathComponent(filename)

        guard let dest = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.jpeg.identifier as CFString,
            1, nil
        ) else { return nil }

        let opts: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: Config.jpegQuality,
        ]
        CGImageDestinationAddImage(dest, image, opts as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return url
    }

    private static func downscale(_ image: CGImage, maxDimension: Int) -> CGImage? {
        let width = image.width
        let height = image.height
        let maxCurrent = max(width, height)
        if maxCurrent <= maxDimension { return image }

        let scale = Double(maxDimension) / Double(maxCurrent)
        let newWidth = Int(Double(width) * scale)
        let newHeight = Int(Double(height) * scale)

        let colorSpace = image.colorSpace ?? CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue
            | CGBitmapInfo.byteOrder32Little.rawValue

        guard let context = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }

        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        return context.makeImage()
    }
}
