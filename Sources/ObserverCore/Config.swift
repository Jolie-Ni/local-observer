import Foundation

public enum Config {
    public static let captureIntervalSeconds: TimeInterval = 30
    public static let idleThresholdSeconds: TimeInterval = 120
    public static let retentionDays: Int = 30
    public static let screenshotMaxDimension: Int = 1920
    public static let jpegQuality: Double = 0.5

    public static let storageDir: URL = {
        let base = FileManager.default.homeDirectoryForCurrentUser
        return base
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .appendingPathComponent("LocalObserver", isDirectory: true)
    }()

    public static let screenshotsDir: URL =
        storageDir.appendingPathComponent("screenshots", isDirectory: true)

    public static let dbPath: String =
        storageDir.appendingPathComponent("observer.sqlite").path

    public static let excludedBundleIDs: Set<String> = [
        "com.agilebits.onepassword7",
        "com.1password.1password",
        "com.1password.1password8",
        "com.apple.keychainaccess",
        "com.apple.loginwindow",
    ]

    public static let excludedURLHostFragments: [String] = [
        "bank", "chase.com", "wellsfargo.com", "1password.com",
    ]
}
