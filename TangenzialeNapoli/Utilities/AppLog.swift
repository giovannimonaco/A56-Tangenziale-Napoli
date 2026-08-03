//
//  AppLog.swift
//  TangenzialeNapoli
//
//  Lightweight console logging for debugging the data flow. Debug-only.
//  Filter the Xcode console by "[A56]" to see everything.
//

import Foundation

nonisolated enum AppLog {
    static func log(_ message: @autoclosure () -> String, _ tag: String = "·") {
        #if DEBUG
        print("🛣️ [A56][\(tag)] \(message())")
        #endif
    }
}
