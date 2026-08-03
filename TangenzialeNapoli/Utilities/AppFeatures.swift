//
//  AppFeatures.swift
//  TangenzialeNapoli
//
//  Product switches that intentionally stay simple and code-controlled.
//

enum AppFeatures {
    /// Set to `false` to remove the local archive entry from Info.
    ///
    /// The technical cache still remains active because it is what keeps an
    /// overnight closure visible after the planned feed has removed it.
    static let showsLocalHistoryInInfo = true
}
