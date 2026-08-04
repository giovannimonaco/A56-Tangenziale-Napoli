import Foundation

/// Debug-only console logging. Filter the Xcode console by "[A56]".
nonisolated enum AppLog {
    static func log(_ message: @autoclosure () -> String, _ tag: String = "·") {
        #if DEBUG
        print("[A56][\(tag)] \(message())")
        #endif
    }
}
