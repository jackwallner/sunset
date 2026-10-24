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
}
