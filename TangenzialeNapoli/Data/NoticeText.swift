import Foundation

/// Parsers for the official Italian notice text (`t_des_it`). Both feeds use
/// the same phrasing, so planned and real-time mappers share these.
nonisolated enum NoticeText {

    // MARK: - Suggested alternatives

    /// Matches "Entrata consigliata verso Pozzuoli: Camaldoli." and
    /// "Uscita consigliata provenendo da Allacc. Diramazione Capodichino: Agnano."
    private static let suggestionExpression = try? NSRegularExpression(
        pattern: "(entrata|uscita)\\s+consigliat[ao](?:\\s+(verso|provenendo\\s+da)\\s+([^:]+))?:\\s*([^.;\\n]+)",
        options: [.caseInsensitive]
    )

    static func suggestions(in text: String) -> [AlternativeSuggestion] {
        guard !text.isEmpty, let suggestionExpression else { return [] }

        let nsText = text as NSString
        var found: [AlternativeSuggestion] = []
        suggestionExpression.enumerateMatches(
            in: text,
            range: NSRange(location: 0, length: nsText.length)
        ) { match, _, _ in
            guard let match, match.numberOfRanges == 5 else { return }

            let kindWord = A56Line.normalize(nsText.substring(with: match.range(at: 1)))
            let qualifier = substring(nsText, at: match.range(at: 2))
            let qualifierPlace = substring(nsText, at: match.range(at: 3))
            let target = nsText.substring(with: match.range(at: 4))

            let direction = suggestionDirection(qualifier: qualifier, place: qualifierPlace)
            guard let exit = A56Line.resolveExit(named: target) else {
                AppLog.log("unresolved suggestion target: \(target)", "map")
                return
            }
            let suggestion = AlternativeSuggestion(
                exitNumber: exit,
                kind: kindWord == "uscita" ? .exitBefore : .reentryAfter,
                direction: direction
            )
            if !found.contains(suggestion) { found.append(suggestion) }
        }
        return found
    }

    /// "verso X" is the travel direction itself; "provenendo da Y" is the
    /// direction leaving Y, i.e. the opposite endpoint.
    private static func suggestionDirection(
        qualifier: String?,
        place: String?
    ) -> Direction? {
        guard let qualifier, let place else { return nil }
        let normalizedPlace = A56Line.normalize(place)
        let towardPlace: Direction
        if normalizedPlace.contains("pozzuoli") {
            towardPlace = .towardPozzuoli
        } else if normalizedPlace.contains("capodichino") {
            towardPlace = .towardCapodichino
        } else {
            return nil
        }
        if A56Line.normalize(qualifier).hasPrefix("verso") {
            return towardPlace
        }
        return towardPlace == .towardPozzuoli ? .towardCapodichino : .towardPozzuoli
    }

    // MARK: - Segment endpoints

    /// Matches "Tratto Chiuso tra Agnano e Cuma dalle ore 23:00 …" (planned)
    /// and "Tratto Chiuso tra Agnano e Cuma fino alle …" (real time).
    private static let segmentExpression = try? NSRegularExpression(
        pattern: "tratto\\s+chiuso\\s+tra\\s+(.+?)\\s+e\\s+(.+?)(?:\\s+(?:dalle|fino|per|in\\s+direzione|verso)\\b|[.,;]|$)",
        options: [.caseInsensitive]
    )

    static func segmentEndpoints(in text: String) -> (Int, Int)? {
        guard !text.isEmpty, let segmentExpression else { return nil }

        let nsText = text as NSString
        guard let match = segmentExpression.firstMatch(
            in: text,
            range: NSRange(location: 0, length: nsText.length)
        ), match.numberOfRanges >= 3,
              let first = A56Line.resolveExit(named: nsText.substring(with: match.range(at: 1))),
              let second = A56Line.resolveExit(named: nsText.substring(with: match.range(at: 2)))
        else { return nil }
        return (first, second)
    }

    // MARK: - Times in the notice

    /// Matches "fino alle 06:00 del 06/08/2026" (Naples local time).
    private static let endExpression = try? NSRegularExpression(
        pattern: "fino alle\\s+(\\d{1,2}):(\\d{2})\\s+del\\s+(\\d{2})/(\\d{2})/(\\d{4})",
        options: [.caseInsensitive]
    )

    static func endDate(in text: String) -> Date? {
        guard !text.isEmpty, let endExpression else { return nil }

        let nsText = text as NSString
        guard let match = endExpression.firstMatch(
            in: text,
            range: NSRange(location: 0, length: nsText.length)
        ), match.numberOfRanges == 6 else { return nil }

        let values = (1...5).compactMap { Int(nsText.substring(with: match.range(at: $0))) }
        guard values.count == 5 else { return nil }
        var components = DateComponents()
        components.hour = values[0]
        components.minute = values[1]
        components.day = values[2]
        components.month = values[3]
        components.year = values[4]
        components.timeZone = TimeZone(identifier: "Europe/Rome")
        return Calendar(identifier: .gregorian).date(from: components)
    }

    /// Matches "dalle ore 23:00" / "dalle 23:00".
    private static let startTimeExpression = try? NSRegularExpression(
        pattern: "dalle\\s+(?:ore\\s+)?(\\d{1,2}):(\\d{2})",
        options: [.caseInsensitive]
    )

    static func startTime(in text: String) -> (hour: Int, minute: Int)? {
        guard !text.isEmpty, let startTimeExpression else { return nil }

        let nsText = text as NSString
        guard let match = startTimeExpression.firstMatch(
            in: text,
            range: NSRange(location: 0, length: nsText.length)
        ), match.numberOfRanges == 3,
              let hour = Int(nsText.substring(with: match.range(at: 1))),
              let minute = Int(nsText.substring(with: match.range(at: 2))),
              (0...23).contains(hour), (0...59).contains(minute)
        else { return nil }
        return (hour, minute)
    }

    private static func substring(_ text: NSString, at range: NSRange) -> String? {
        range.location == NSNotFound ? nil : text.substring(with: range)
    }
}
