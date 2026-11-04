import XCTest
@testable import Sunset

final class ThemeContrastTests: XCTestCase {
    /// `Theme.textSecondary` drawn over a colour, against that colour.
    private func secondaryTextContrast(on background: RGB) -> Double {
        let text = RGB(1, 1, 1).mixed(with: background, 0.14)
        return (text.luminance + 0.05) / (background.luminance + 0.05)
    }

    func testSecondaryTextReadsOnEveryDayCardSky() {
        for score in 0 ... 100 {
            for event in SunEvent.allCases {
                for color in Theme.readableSkyRGB(score: score, event: event) {
                    XCTAssertGreaterThanOrEqual(secondaryTextContrast(on: color), 4.5, "score \(score), \(event)")
                }
            }
        }
    }

    func testReadableLeavesDarkColoursAlone() {
        let dark = RGB(0.20, 0.10, 0.42)
        XCTAssertEqual(dark.readable.red, dark.red)
        XCTAssertEqual(dark.readable.blue, dark.blue)
    }
}
