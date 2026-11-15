import Foundation

nonisolated enum AppLinks {
    static let plannedNotices = URL(string: "https://www.autostrade.it/it/previsioni?strada=A56")!
    static let liveTraffic = URL(string: "https://www.tangenzialedinapoli.it/it/servizi/traffico/traffico-in-campania")!
    static let autostradePrivacy = URL(string: "https://www.autostrade.it/it/privacy/sito-web")!
    static let appleMapsPrivacy = URL(string: "https://www.apple.com/legal/privacy/data/it/apple-maps/")!
    static let appleMapsTerms = URL(string: "https://www.apple.com/legal/internet-services/maps/terms-it.html")!
    // Public issue tracker; never ask users to post location or private information here.
    static let support = URL(string: "https://github.com/giovannimonaco/A56-Tangenziale-Napoli/issues")!
    static let contact = URL(string: "mailto:mon.giovanni@gmail.com")!
    // Verified public policy on 15 Nov 2026; main/docs/privacy.md does not exist yet.
    // Before release, publish the updated policy (including widgets) and verify this
    // URL again, or move to its permanent main/site URL. See docs/app-store/readiness.md.
    static let privacyPolicy = URL(string: "https://github.com/giovannimonaco/A56-Tangenziale-Napoli/blob/review/general-audit/docs/privacy.md")!
}
