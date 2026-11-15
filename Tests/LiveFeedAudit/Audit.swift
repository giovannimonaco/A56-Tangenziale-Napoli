import Foundation

/// Explicit, nondeterministic audit, intentionally separate from the unit suite.
@main
struct LiveFeedAudit {
    static func main() async {
        do {
            let arguments = Array(CommandLine.arguments.dropFirst())
            if arguments == ["--live"] {
                let result = try await LiveClosureProvider().fetchClosures()
                guard let quality = result.quality else { throw AuditError.missingQuality }
                try printJSON([
                    "mode": "live-production-provider", "observedAt": ISO8601DateFormatter().string(from: Date()),
                    "closureCount": result.closures.count,
                    "physicalSegmentCount": result.closures.filter { $0.reportedSegment != nil }.count,
                    "isFullyVerified": quality.isFullyVerified,
                    "plannedFeedAvailable": quality.plannedFeedAvailable,
                    "realtimeFeedAvailable": quality.realtimeFeedAvailable,
                    "expectedRecords": quality.expectedRecords, "mappedRecords": quality.mappedRecords,
                    "unresolvedRecords": quality.unresolvedRecords, "topologyIssues": quality.topologyIssues,
                    "canInferCancellations": result.canInferCancellations,
                    "canRevalidateActive": result.canRevalidateActive
                ])
                if !quality.isFullyVerified { exit(1) }
            } else if arguments.count == 3, arguments[0] == "--snapshots" {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let feeds = try arguments.dropFirst().map {
                    try decoder.decode(AutostradeFeed.self, from: Data(contentsOf: URL(fileURLWithPath: $0)))
                }
                let now = Date()
                let planned = AutostradeClosureMapper.mappingReport(from: feeds[0].events, now: now)
                let realtime = AutostradeRealtimeClosureMapper.mappingReport(from: feeds[1].events, now: now)
                let complete = planned.hasCompleteCoverage && realtime.hasCompleteCoverage
                    && feeds.allSatisfy { $0.undecodedEventCount == 0 && !$0.events.isEmpty }
                let issues = (planned.issues + realtime.issues).map { issue -> [String: Any] in
                    ["eventID": issue.eventID, "summary": issue.summary,
                     "occurrenceCount": issue.occurrenceCount, "coveredByMappedWindow": issue.coveredByMappedWindow]
                }
                try printJSON([
                    "mode": "snapshot-mapping-only", "observedAt": ISO8601DateFormatter().string(from: now),
                    "note": "HTTP availability and publication freshness are checked only in --live mode.",
                    "mappingHasCompleteCoverage": complete,
                    "plannedNationalRows": feeds[0].events.count,
                    "plannedUndecodedRows": feeds[0].undecodedEventCount,
                    "plannedExpected": planned.expectedOccurrences, "plannedMapped": planned.mappedOccurrences,
                    "physicalSegmentCount": planned.closures.filter { $0.reportedSegment != nil }.count
                        + realtime.closures.filter { $0.reportedSegment != nil }.count,
                    "realtimeNationalRows": feeds[1].events.count,
                    "realtimeUndecodedRows": feeds[1].undecodedEventCount,
                    "realtimeExpected": realtime.expectedEvents, "realtimeMapped": realtime.mappedEvents,
                    "issues": issues, "staticTopologyIssues": A56Line.validationIssues
                ])
                if !complete || !A56Line.validationIssues.isEmpty { exit(1) }
            } else {
                throw AuditError.usage
            }
        } catch {
            FileHandle.standardError.write(Data("A56 feed audit: \(error)\n".utf8))
            exit(1)
        }
    }

    private static func printJSON(_ object: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        print(String(decoding: data, as: UTF8.self))
    }

    private enum AuditError: Error {
        case usage // Use --live, or --snapshots <previsioni.json> <eventi.json>.
        case missingQuality
    }
}
