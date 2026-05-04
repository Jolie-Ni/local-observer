import CoreGraphics
import Vision

final class OCR {
    /// Run on-device OCR via the Vision framework. Free, fast, no network.
    func recognize(image: CGImage) -> String {
        var output = ""
        let request = VNRecognizeTextRequest { request, _ in
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                return
            }
            output = observations
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")
        }
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return ""
        }
        return output
    }
}
