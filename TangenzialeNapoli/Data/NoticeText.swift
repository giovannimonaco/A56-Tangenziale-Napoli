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

        let text = text.replacingOccurrences(of: #"\bS\.\s*S\.\s*"#, with: "SS ", options: [.regularExpression, .caseInsensitive])
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
            guard qualifier == nil || direction != nil else { return }
            let normalizedTarget = A56Line.normalize(target)
            let externalPlace = ["ss domitiana", "ss 7 quater domitiana"].contains(normalizedTarget)
                ? "SS Domitiana" : nil
            let exit = externalPlace == nil ? A56Line.resolveSuggestedExit(named: target) : nil
            guard exit != nil || externalPlace != nil else {
                AppLog.log("unresolved suggestion target: \(target)", "map")
                return
            }
            let suggestion = AlternativeSuggestion(
                exitNumber: exit,
                externalPlace: externalPlace,
                kind: kindWord == "uscita" ? .exitBefore : .reentryAfter,
                direction: direction
            )
            if suggestion.label != nil, !found.contains(suggestion) { found.append(suggestion) }
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
        guard let towardPlace = direction(named: place) else { return nil }
        if A56Line.normalize(qualifier).hasPrefix("verso") {
            return towardPlace
        }
        return towardPlace == .towardPozzuoli ? .towardCapodichino : .towardPozzuoli
    }

    static func direction(named text: String) -> Direction? {
        let words = Set(A56Line.normalize(text).split { !$0.isLetter })
        let east = !words.isDisjoint(with: ["capodichino", "casoria", "est", "autostrade"])
        let west = !words.isDisjoint(with: ["pozzuoli", "ovest"])
        guard east != west else { return nil }
        return east ? .towardCapodichino : .towardPozzuoli
    }

    private static let noticeDirectionExpression = try? NSRegularExpression(
        pattern: #"\b(verso|provenendo\s+da)\s+(.+?)(?:\s+per\b|[.;]|$)"#,
        options: [.caseInsensitive]
    )

    static func travelDirection(in text: String) -> Direction? {
        let string = text as NSString
        let range = NSRange(location: 0, length: string.length)
        let end = suggestionExpression?.firstMatch(in: text, range: range)?.range.location ?? string.length
        // The feed abbreviates “Allacciamento” in direction qualifiers.
        let main = string.substring(to: end).replacingOccurrences(of: "Allacc.", with: "Allacciamento", options: .caseInsensitive)
        let mainString = main as NSString
        guard let match = noticeDirectionExpression?.firstMatch(in: main, range: NSRange(location: 0, length: mainString.length)) else { return nil }
        return suggestionDirection(qualifier: substring(mainString, at: match.range(at: 1)),
                                   place: substring(mainString, at: match.range(at: 2)))
    }

    private static let rampExpressions = [
        #"^\s*(?:l['’])?(?:uscita|entrata)\s+(?:di\s+)?(.+?)\s+(?:e['’]|è|sarà)\s+chius"#,
        #"^\s*(?:entrata\s+)?(.+?)\s+in\s+(?:entrata|uscita)\s+(?:e['’]|è|sarà)\s+chius"#
    ].compactMap { try? NSRegularExpression(pattern: $0, options: [.caseInsensitive]) }

    static func rampExit(in text: String) -> Int? {
        let string = text as NSString
        for expression in rampExpressions {
            if let match = expression.firstMatch(in: text, range: NSRange(location: 0, length: string.length)),
               let name = substring(string, at: match.range(at: 1)), let exit = A56Line.resolveExit(named: name) {
                return exit
            }
        }
        return nil
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
        pattern: "fino\\s+alle\\s+(?:ore\\s+)?(\\d{1,2})[:.,](\\d{2})\\s+del(?:\\s+giorno)?\\s+(\\d{1,2})/(\\d{1,2})/(\\d{4})",
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
        return localDate(hour: values[0], minute: values[1], day: values[2], month: values[3], year: values[4])
    }

    private static let plannedWindowExpression = try? NSRegularExpression(
        pattern: "dalle\\s+(?:ore\\s+)?(\\d{1,2})[:.,](\\d{2})\\s+alle\\s+(?:ore\\s+)?(\\d{1,2})[:.,](\\d{2})\\s+dal(?:\\s+giorno)?\\s+(\\d{1,2})/(\\d{1,2})/(\\d{4})\\s+al(?:\\s+giorno)?\\s+(\\d{1,2})/(\\d{1,2})/(\\d{4})",
        options: [.caseInsensitive]
    )

    /// The prose describes the first start and last end, even for nightly work.
    static func plannedBounds(in text: String) -> RoadClosure.ReportedWindow? {
        let string = text as NSString
        guard let match = plannedWindowExpression?.firstMatch(in: text, range: NSRange(location: 0, length: string.length)) else { return nil }
        let values = (1...10).compactMap { Int(string.substring(with: match.range(at: $0))) }
        guard values.count == 10,
              let start = localDate(hour: values[0], minute: values[1], day: values[4], month: values[5], year: values[6]),
              let end = localDate(hour: values[2], minute: values[3], day: values[7], month: values[8], year: values[9]),
              start < end else { return nil }
        return .init(start: start, end: end)
    }

    private static func localDate(hour: Int, minute: Int, day: Int, month: Int, year: Int) -> Date? {
        guard (0..<60).contains(minute), (0..<24).contains(hour) || (hour == 24 && minute == 0) else { return nil }
        let components = DateComponents(year: year, month: month, day: day, hour: hour == 24 ? 0 : hour, minute: minute)
        let calendar = ClosureFormat.calendar
        guard components.isValidDate(in: calendar), let date = calendar.date(from: components) else { return nil }
        return hour == 24 ? calendar.date(byAdding: .day, value: 1, to: date) : date
    }

    private static func substring(_ text: NSString, at range: NSRange) -> String? {
        range.location == NSNotFound ? nil : text.substring(with: range)
    }
}
