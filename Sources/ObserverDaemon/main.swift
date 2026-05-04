import Foundation
import ObserverCore

// Disable stdout block-buffering so logs show up live when redirected to a file.
setbuf(stdout, nil)

PermissionCheck.runDiagnostic()

let coordinator = CaptureCoordinator()

signal(SIGINT, SIG_IGN)
signal(SIGTERM, SIG_IGN)

let sigintSrc = DispatchSource.makeSignalSource(signal: SIGINT, queue: .main)
sigintSrc.setEventHandler {
    print("\n[observer] shutting down…")
    coordinator.stop()
    exit(0)
}
sigintSrc.resume()

let sigtermSrc = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
sigtermSrc.setEventHandler {
    coordinator.stop()
    exit(0)
}
sigtermSrc.resume()

print("[observer] starting capture daemon (Ctrl+C to stop)")
print("[observer] storage: \(Config.storageDir.path)")
print("[observer] capture interval: \(Int(Config.captureIntervalSeconds))s")

coordinator.start()
RunLoop.main.run()
