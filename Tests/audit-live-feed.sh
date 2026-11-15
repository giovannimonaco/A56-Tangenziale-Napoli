#!/bin/bash
set -euo pipefail

# Explicit online/snapshot audit. Never run this nondeterministic check as CI's unit suite.
cd "$(dirname "$0")/.."
audit_dir="$(mktemp -d)"
trap 'rm -rf "$audit_dir"' EXIT
xcrun --sdk macosx swiftc -O \
    Tests/ColorResources.swift Tests/LiveFeedAudit/Audit.swift \
    TangenzialeNapoli/Data/{A56Line,A56RouteGeometry,A56TripMatcher,AutostradeClosureMapper,AutostradeEvent,AutostradeRealtimeClosureMapper,NoticeText}.swift \
    TangenzialeNapoli/Data/{ClosureArchive,ClosureMatching,ClosureProvider,LiveClosureProvider,SampleClosures}.swift \
    TangenzialeNapoli/Models/{A56Exit,AlternativeSuggestion,ClosureRampImpact,Direction,RoadClosure,Severity}.swift \
    TangenzialeNapoli/ViewModels/ClosuresViewModel.swift \
    TangenzialeNapoli/Utilities/{AppLog,DateFormatting}.swift -o "$audit_dir/audit"
"$audit_dir/audit" "$@"
