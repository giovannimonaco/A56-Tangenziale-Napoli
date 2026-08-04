/// Compile-time product switches.
enum AppFeatures {
    /// Set to `false` to hide the local archive entry in Info. The underlying
    /// cache stays active either way: it is what keeps an overnight closure
    /// visible after the planned feed has dropped it.
    static let showsLocalHistoryInInfo = true
}
