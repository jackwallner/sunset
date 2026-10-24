import XCTest
@testable import Sunset

final class UnfoldedSplitTests: XCTestCase {
    /// iPhone Duo inner display, landscape, in points.
    private let unfolded: CGFloat = 951

    func testCompactWidthNeverSplits() {
        XCTAssertNil(UnfoldedSplit.make(width: 466, isRegularWidth: false, fold: nil))
        XCTAssertNil(UnfoldedSplit.make(width: unfolded, isRegularWidth: false, fold: 470...481))
    }

    func testRegularWidthTooNarrowForTwoPanesStaysOneColumn() {
        // The unfolded display held in portrait.
        XCTAssertNil(UnfoldedSplit.make(width: 669, isRegularWidth: true, fold: nil))
    }

    func testPanesMeetTheFoldEdges() {
        let split = UnfoldedSplit.make(width: unfolded, isRegularWidth: true, fold: 470...481)
        XCTAssertEqual(split, UnfoldedSplit(primaryWidth: 470, secondaryX: 481, secondaryWidth: 470))
    }

    func testNoFoldSplitsEvenly() {
        let split = UnfoldedSplit.make(width: unfolded, isRegularWidth: true, fold: nil)
        XCTAssertEqual(split, UnfoldedSplit(primaryWidth: 475, secondaryX: 475, secondaryWidth: 476))
    }

    func testFoldLeavingANarrowPaneFallsBackToAnEvenSplit() {
        let split = UnfoldedSplit.make(width: unfolded, isRegularWidth: true, fold: 300...310)
        XCTAssertEqual(split, UnfoldedSplit(primaryWidth: 475, secondaryX: 475, secondaryWidth: 476))
    }

    func testZeroWidthFoldSplitsAtTheCrease() {
        let split = UnfoldedSplit.make(width: 1000, isRegularWidth: true, fold: 480...480)
        XCTAssertEqual(split, UnfoldedSplit(primaryWidth: 480, secondaryX: 480, secondaryWidth: 520))
    }

    func testMeasuredGeometryMatchesTheRawInputs() {
        let geometry = PaneGeometry(width: unfolded, fold: 470...481)
        XCTAssertEqual(
            UnfoldedSplit.make(geometry, isRegularWidth: true),
            UnfoldedSplit.make(width: unfolded, isRegularWidth: true, fold: 470...481)
        )
        XCTAssertNil(UnfoldedSplit.make(PaneGeometry(), isRegularWidth: true))
    }

    // Pane detail: a show picked in the trailing Outlook.

    func testPickInTheOutlookOpensOnTodayFromAnyLeadingTab() {
        let show = DemoForecast.make().days[0].sunset
        XCTAssertEqual(PaneDetail.tab(after: show, current: 2), PaneDetail.tab)
        XCTAssertEqual(PaneDetail.tab(after: show, current: 0), PaneDetail.tab)
    }

    func testClearingThePickKeepsTheLeadingTab() {
        XCTAssertEqual(PaneDetail.tab(after: nil, current: 2), 2)
    }

    func testShowsHashByTheirMoment() {
        let day = DemoForecast.make().days[0]
        XCTAssertEqual(Set([day.sunset, day.sunset, day.sunrise]).count, 2)
    }

    // Pane clearance: the leading pane's tab bar inset is 81 pt.

    func testFoldedClearanceHidesNothing() {
        XCTAssertEqual(PaneClearance.make(isSplit: false, barInset: 81), PaneClearance(hidden: 0, contentMargin: nil))
    }

    func testSplitClearanceEndsContentAGapAboveTheBar() {
        let clearance = PaneClearance.make(isSplit: true, barInset: 81)
        XCTAssertEqual(clearance.hidden, 81 + PaneClearance.gap)
        // The last row can scroll up to the line, so it is never cut.
        XCTAssertEqual(clearance.contentMargin, PaneClearance.gap)
        XCTAssertEqual(PaneClearance.make(isSplit: true, barInset: -4).hidden, PaneClearance.gap)
    }

    func testTrailingPaneRunsToTheDisplayEdge() {
        XCTAssertEqual(PaneClearance.make(isSplit: true, hasBar: false, barInset: 20), PaneClearance(hidden: 0, contentMargin: nil))
    }

    // Pane cut: the line sits at 577 in each case.

    private func card(_ id: String, _ minY: CGFloat, _ maxY: CGFloat) -> PaneCut.Part {
        PaneCut.Part(block: id, frame: CGRect(x: 16, y: minY, width: 438, height: maxY - minY), isRow: false, style: .card)
    }

    private func row(_ id: String, _ minY: CGFloat, _ maxY: CGFloat, style: PaneCut.Style = .card) -> PaneCut.Part {
        PaneCut.Part(block: id, frame: CGRect(x: 34, y: minY, width: 402, height: maxY - minY), isRow: true, style: style)
    }

    func testBlocksJoinTheirPartsAndBreakBelowEachRow() {
        let blocks = PaneCut.blocks(from: [card("a", 400, 700), row("a", 440, 500), row("a", 514, 574)])
        XCTAssertEqual(blocks, [PaneCut.Block(
            frame: CGRect(x: 16, y: 400, width: 438, height: 300),
            breaks: [500 + PaneCut.Style.card.padding, 574 + PaneCut.Style.card.padding],
            radius: Theme.cardRadius
        )])
    }

    func testNothingSlicedCutsAtTheLine() {
        let blocks = PaneCut.blocks(from: [card("a", 100, 300), card("b", 316, 570)])
        XCTAssertEqual(PaneCut.make(line: 577, blocks: blocks), PaneCut(y: 577, closes: nil))
    }

    func testASlicedCardEndsBelowItsLastWholeRow() {
        // Factor rows: the third crosses the line, so the card ends below the second.
        let blocks = PaneCut.blocks(from: [
            card("factors", 380, 760), row("factors", 440, 500), row("factors", 514, 556), row("factors", 570, 630),
        ])
        let closing = PaneCut.Closing(minX: 16, maxX: 454, radius: Theme.cardRadius)
        XCTAssertEqual(PaneCut.make(line: 577, blocks: blocks), PaneCut(y: 556 + PaneCut.Style.card.padding, closes: closing))
    }

    func testARowWhosePaddingWouldCrossTheLineGoesToo() {
        let blocks = PaneCut.blocks(from: [card("a", 380, 760), row("a", 440, 500), row("a", 514, 570)])
        XCTAssertEqual(PaneCut.make(line: 577, blocks: blocks).y, 500 + PaneCut.Style.card.padding)
    }

    func testACardWithNoWholeRowAboveTheLineHidesWhole() {
        let blocks = PaneCut.blocks(from: [card("a", 300, 500), card("b", 516, 700), row("b", 560, 620)])
        XCTAssertEqual(PaneCut.make(line: 577, blocks: blocks), PaneCut(y: 516, closes: nil))
    }

    func testAListSectionClosesBelowItsLastWholeCell() {
        let section = [
            PaneCut.Part(block: "location", frame: CGRect(x: 36, y: 470, width: 100, height: 20), isRow: false, style: .groupedList),
            row("location", 496, 548, style: .groupedList),
            row("location", 548, 600, style: .groupedList),
        ]
        let cut = PaneCut.make(line: 577, blocks: PaneCut.blocks(from: section))
        XCTAssertEqual(cut, PaneCut(y: 548, closes: PaneCut.Closing(minX: 34, maxX: 436, radius: PaneCut.Style.groupedList.radius)))
    }

    func testAHeaderWhoseRowsDoNotFitGoesWithThem() {
        let section = [
            PaneCut.Part(block: "about", frame: CGRect(x: 36, y: 540, width: 100, height: 20), isRow: false, style: .groupedList),
            row("about", 566, 618, style: .groupedList),
        ]
        XCTAssertEqual(PaneCut.make(line: 577, blocks: PaneCut.blocks(from: section)), PaneCut(y: 540, closes: nil))
    }

    // Pane fill: the leading pane's viewport above the tab bar is 587 pt.

    func testTheHeroTakesTheRoomTheCardsLeaveAboveTheLine() {
        let hero = PaneFill.heroHeight(viewport: 587, spacing: 54, cards: [138, 164], minimum: 200)
        XCTAssertEqual(hero, 587 - PaneClearance.gap - 54 - 138 - 164)
        // Hero, padding and cards end exactly on the line, so nothing is cut.
        XCTAssertEqual(hero! + 54 + 138 + 164, 587 - PaneClearance.gap)
    }

    func testTheHeroNeverShrinksBelowItsMinimum() {
        XCTAssertEqual(PaneFill.heroHeight(viewport: 587, spacing: 54, cards: [138, 340], minimum: 200), 200)
    }

    func testTheHeroWaitsForEveryHeight() {
        XCTAssertNil(PaneFill.heroHeight(viewport: 0, spacing: 54, cards: [138, 164], minimum: 200))
        XCTAssertNil(PaneFill.heroHeight(viewport: 587, spacing: 54, cards: [138, 0], minimum: 200))
        XCTAssertNil(PaneFill.heroHeight(viewport: 587, spacing: 54, cards: [], minimum: 200))
    }

    // Status column: its clock ends 112 pt down, the Outlook's first card 83.

    func testContentStartsBelowTheStatusColumnsClock() {
        XCTAssertEqual(StatusColumn.clockPadding(columnWidth: 85), StatusColumn.clockClearance)
        XCTAssertGreaterThanOrEqual(83 + StatusColumn.clockPadding(columnWidth: 85), 112 + 6)
    }

    func testNoColumnNeedsNoPadding() {
        XCTAssertEqual(StatusColumn.clockPadding(columnWidth: 0), 0)
    }

    func testTightCardsNeverShowTheNextRowsTop() {
        // Day cards in the trailing pane space their rows 10 pt apart.
        XCTAssertLessThan(PaneCut.Style.tightCard.padding, 10)
        let blocks = PaneCut.blocks(from: [
            card("d", 520, 700),
            row("d", 560, 604, style: .tightCard),
            row("d", 614, 658, style: .tightCard),
            row("d", 668, 690, style: .tightCard),
        ])
        XCTAssertEqual(PaneCut.make(line: 669, blocks: blocks).y, 658 + PaneCut.Style.tightCard.padding)
    }
}
