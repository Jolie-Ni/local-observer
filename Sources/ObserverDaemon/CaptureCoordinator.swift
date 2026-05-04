import Foundation
import ObserverCore

final class CaptureCoordinator {
    private var timer: Timer?
    private let storage: Storage
    private let ocr = OCR()
    private let redactor = Redactor()
    private var lastPurgeDate: Date = .distantPast

    init() {
        try? FileManager.default.createDirectory(
            at: Config.storageDir, withIntermediateDirectories: true)
        try? FileManager.default.createDirectory(
            at: Config.screenshotsDir, withIntermediateDirectories: true)

        do {
            self.storage = try Storage(path: Config.dbPath)
        } catch {
            fatalError("[observer] failed to open storage: \(error)")
        }
    }

    func start() {
        let t = Timer(timeInterval: Config.captureIntervalSeconds, repeats: true) { [weak self] _ in
            self?.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        // Fire one immediately so the first sample doesn't take 30s.
        tick()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        // Maintenance: purge old captures once a day.
        if Date().timeIntervalSince(lastPurgeDate) > 86_400 {
            try? storage.purgeOlderThan(days: Config.retentionDays)
            lastPurgeDate = Date()
        }

        if IdleDetector.idleSeconds() > Config.idleThresholdSeconds {
            return
        }

        guard let app = ActiveApp.frontmost() else { return }
        let appName = app.localizedName ?? "unknown"
        let bundleID = app.bundleIdentifier

        if let bid = bundleID, Config.excludedBundleIDs.contains(bid) {
            return
        }

        let windowTitle = ActiveApp.focusedWindowTitle(pid: app.processIdentifier)
        let url = BrowserURL.fetch(bundleID: bundleID)

        if let u = url, isExcludedURL(u) { return }

        guard let image = Screenshot.capture() else {
            print("[observer] screenshot failed (permission?)")
            return
        }

        let screenshotPath = Screenshot.save(image, dir: Config.screenshotsDir)
        let rawOCR = ocr.recognize(image: image)
        let redactedOCR = redactor.redact(rawOCR)
        let isRedacted = redactedOCR != rawOCR

        let capture = Capture(
            ts: Date(),
            appName: appName,
            windowTitle: windowTitle,
            url: url,
            screenshotPath: screenshotPath?.path,
            ocrText: redactedOCR,
            isRedacted: isRedacted,
            excluded: false
        )

        do {
            try storage.insert(capture: capture)
            let preview = (windowTitle ?? "—").prefix(60)
            let urlPreview = url.map { "  \($0)" } ?? ""
            print("[observer] \(appName) | \(preview)\(urlPreview)")
        } catch {
            print("[observer] insert failed: \(error)")
        }
    }

    private func isExcludedURL(_ raw: String) -> Bool {
        guard let host = URL(string: raw)?.host?.lowercased() else { return false }
        for fragment in Config.excludedURLHostFragments {
            if host.contains(fragment) { return true }
        }
        return false
    }
}
