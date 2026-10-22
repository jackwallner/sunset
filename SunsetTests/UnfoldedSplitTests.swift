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
}
