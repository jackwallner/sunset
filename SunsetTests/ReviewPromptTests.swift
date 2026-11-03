import XCTest
@testable import Sunset

final class ReviewPromptTests: XCTestCase {
    private func eligible(
        asked: Bool = false, onboarded: Bool = true, opens: Int = 3, days: Int = 2, score: Int = 60
    ) -> Bool {
        AlertSettings.reviewEligible(
            asked: asked, onboarded: onboarded, opens: opens, daysSinceFirstOpen: days, score: score
        )
    }

    func testAsksAfterThreeOpensOverTwoDaysForAGoodShow() {
        XCTAssertTrue(eligible())
    }

    func testNeverAsksOnTheFirstDayHoweverManyOpens() {
        XCTAssertFalse(eligible(opens: 10, days: 0))
        XCTAssertFalse(eligible(opens: 10, days: 1))
    }

    func testNeverAsksTwiceBeforeOnboardingOrForAPoorShow() {
        XCTAssertFalse(eligible(asked: true))
        XCTAssertFalse(eligible(onboarded: false))
        XCTAssertFalse(eligible(opens: 2))
        XCTAssertFalse(eligible(score: 59))
    }
}
