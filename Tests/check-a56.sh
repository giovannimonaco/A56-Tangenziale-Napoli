#!/bin/bash
set -euo pipefail

work_dir="$(mktemp -d)"
trap 'rm -rf "$work_dir"' EXIT
cd "$(dirname "$0")/.."
xcrun --sdk macosx swiftc -O \
    Tests/*.swift \
    TangenzialeNapoli/Data/{A56Line,A56RouteGeometry,A56TripMatcher,AutostradeClosureMapper,AutostradeEvent,AutostradeRealtimeClosureMapper,NoticeText}.swift \
    TangenzialeNapoli/Data/{ClosureArchive,ClosureMatching,ClosureProvider,LiveClosureProvider,SampleClosures}.swift \
    TangenzialeNapoli/Models/{A56Exit,AlternativeSuggestion,ClosureRampImpact,Direction,RoadClosure,Severity}.swift \
    TangenzialeNapoli/ViewModels/ClosuresViewModel.swift \
    TangenzialeNapoli/Utilities/{AppLog,DateFormatting}.swift -o "$work_dir/check-a56"
"$work_dir/check-a56" "$@"
