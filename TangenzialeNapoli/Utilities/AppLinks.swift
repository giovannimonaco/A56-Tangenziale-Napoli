import Foundation

nonisolated enum AppLinks {
    static let plannedNotices = URL(string: "https://www.autostrade.it/it/previsioni?strada=A56")!
    static let liveTraffic = URL(string: "https://www.tangenzialedinapoli.it/it/servizi/traffico/traffico-in-campania")!
    static let autostradePrivacy = URL(string: "https://www.autostrade.it/it/privacy/sito-web")!
    static let appleMapsPrivacy = URL(string: "https://www.apple.com/legal/privacy/data/it/apple-maps/")!
    static let appleMapsTerms = URL(string: "https://www.apple.com/legal/internet-services/maps/terms-it.html")!
    static let support = URL(string: "https://github.com/giovannimonaco/A56-Tangenziale-Napoli/issues")!
    static let privacyPolicy = URL(string: "https://github.com/giovannimonaco/A56-Tangenziale-Napoli/blob/main/docs/privacy.md")!
}
