import XCTest

@MainActor
final class A56UITests: XCTestCase {
    private let app = XCUIApplication(bundleIdentifier: "com.giovannimonaco.TangenzialeNapoli")

    override func setUp() {
        continueAfterFailure = false
    }

    private func launch(_ fixture: String = "--sample-data", tab: String = "closures") {
        app.launchArguments = [
            fixture, "-AppleLanguages", "(it)", "-AppleLocale", "it_IT",
            "-lastSelectedTab", tab, "-selectedDirection", "towardPozzuoli"
        ]
        if tab == "closures" { app.launchArguments.append("--show-closures") }
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Chiusure"].waitForExistence(timeout: 15))
    }

    private func text(containing value: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", value)).firstMatch
    }

    func testTabsAndManualRouteSearch() {
        launch()
        app.tabBars.buttons["Mappa"].tap()
        XCTAssertTrue(app.buttons["Programmate"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Percorsi"].tap()
        let chooseStart = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Scegli partenza")).firstMatch
        XCTAssertTrue(chooseStart.waitForExistence(timeout: 5))
        chooseStart.tap()
        XCTAssertTrue(app.searchFields.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Partenza"].exists)
        app.navigationBars.buttons["Annulla"].tap()
        XCTAssertTrue(app.navigationBars["Percorsi"].waitForExistence(timeout: 5))
    }

    func testUnavailableDataDoesNotConfirmTheRoadIsOpen() {
        launch("--unavailable-data")
        XCTAssertTrue(text(containing: "Avvisi del gestore indisponibili").waitForExistence(timeout: 5))
        XCTAssertFalse(text(containing: "Nessuna chiusura pubblicata").exists)
        XCTAssertFalse(text(containing: "Nessuna chiusura segnalata").exists)
        XCTAssertTrue(app.buttons["Aggiorna dati"].isEnabled)
    }

    func testOfflineSnapshotKeepsItsWarning() {
        launch("--stale-sample-data")
        XCTAssertTrue(text(containing: "Aggiornamento fallito").waitForExistence(timeout: 5))
        app.tabBars.buttons["Mappa"].tap()
        app.tabBars.buttons["Chiusure"].tap()
        XCTAssertTrue(text(containing: "Aggiornamento fallito").waitForExistence(timeout: 5))
    }

    func testWidgetLinkOpensClosuresFromAnotherTab() {
        launch(tab: "trips")
        XCTAssertTrue(app.tabBars.buttons["Percorsi"].isSelected)
        app.open(URL(string: "a56napoli://closures")!)
        XCTAssertTrue(app.navigationBars["Chiusure"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.tabBars.buttons["Chiusure"].isSelected)
    }
}
