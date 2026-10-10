import XCTest
@testable import Sunset

final class SunsetScorerTests: XCTestCase {
    private func sky(low: Double = 0, mid: Double = 0, high: Double = 0, west: Double? = nil,
                     humidity: Double = 45, visibility: Double = 30_000, rain: Double = 0) -> SkyConditions {
        SkyConditions(cloudLow: low, cloudMid: mid, cloudHigh: high, cloudLowTowardSun: west ?? low,
                      humidity: humidity, visibility: visibility, precipitationChance: rain)
    }

    func testCirrusOverClearHorizonIsEpic() {
        let score = SunsetScorer.score(sky(mid: 25, high: 50))
        XCTAssertGreaterThanOrEqual(score.total, 85)
        XCTAssertEqual(score.grade, .epic)
        XCTAssertEqual(score.horizon, 100)
    }

    func testClearSkyIsPlainButNotDull() {
        let score = SunsetScorer.score(sky())
        XCTAssertTrue((35 ... 49).contains(score.total), "clear sky scored \(score.total)")
        XCTAssertEqual(score.grade, .fair)
        XCTAssertTrue(score.summary.contains("clear"))
    }

    func testLowOvercastIsDull() {
        let score = SunsetScorer.score(sky(low: 100, mid: 60, high: 20, humidity: 90, visibility: 8_000))
        XCTAssertLessThan(score.total, 30)
        XCTAssertEqual(score.grade, .dull)
    }

    func testLowCloudToTheWestBlocksEvenWithOpenSkyOverhead() {
        let open = SunsetScorer.score(sky(mid: 20, high: 50, west: 0))
        let blocked = SunsetScorer.score(sky(mid: 20, high: 50, west: 95))
        XCTAssertGreaterThan(open.total - blocked.total, 30)
        XCTAssertTrue(blocked.summary.contains("west"))
    }

    func testRainCutsTheScore() {
        let dry = SunsetScorer.score(sky(mid: 30, high: 50))
        let wet = SunsetScorer.score(sky(mid: 30, high: 50, rain: 80))
        XCTAssertLessThan(wet.total, dry.total / 2 + 10)
        XCTAssertTrue(wet.summary.contains("Rain"))
    }

    func testHumidityAndHazeLowerClarity() {
        let crisp = SunsetScorer.score(sky(high: 45))
        let hazy = SunsetScorer.score(sky(high: 45, humidity: 95, visibility: 4_000))
        XCTAssertEqual(hazy.clarity, 0)
        XCTAssertGreaterThan(crisp.clarity, 85)
        XCTAssertGreaterThan(crisp.total, hazy.total)
    }

    func testScoresStayWithinRange() {
        for low in stride(from: 0.0, through: 100, by: 25) {
            for high in stride(from: 0.0, through: 100, by: 25) {
                let score = SunsetScorer.score(sky(low: low, mid: 50, high: high))
                XCTAssertTrue((0 ... 100).contains(score.total))
                for factor in score.factors {
                    XCTAssertTrue((0 ... 100).contains(factor.value), "\(factor.name) was \(factor.value)")
                }
            }
        }
    }

    func testGradeBoundaries() {
        XCTAssertEqual(SunsetScore.Grade(total: 29), .dull)
        XCTAssertEqual(SunsetScore.Grade(total: 30), .fair)
        XCTAssertEqual(SunsetScore.Grade(total: 50), .good)
        XCTAssertEqual(SunsetScore.Grade(total: 70), .great)
        XCTAssertEqual(SunsetScore.Grade(total: 85), .epic)
    }

    func testInterpolationWeightsTowardTheLaterHour() {
        let before = sky(high: 0)
        let after = sky(high: 100)
        XCTAssertEqual(SunsetScorer.interpolate(before, after, weight: 0.75).cloudHigh, 75, accuracy: 0.001)
        XCTAssertEqual(SunsetScorer.interpolate(before, after, weight: 2).cloudHigh, 100)
    }
}

final class SunriseScoringTests: XCTestCase {
    func testSunriseSummaryLooksEast() {
        let sky = SkyConditions(cloudLow: 0, cloudMid: 20, cloudHigh: 50, cloudLowTowardSun: 95,
                                humidity: 50, visibility: 30_000, precipitationChance: 0)
        let score = SunsetScorer.score(sky, event: .sunrise)
        XCTAssertTrue(score.summary.contains("east"))
        XCTAssertTrue(score.summary.contains("first light"))
    }

    func testRainSummaryNamesTheMoment() {
        let sky = SkyConditions(cloudLow: 0, cloudMid: 0, cloudHigh: 0, cloudLowTowardSun: 0,
                                humidity: 50, visibility: 30_000, precipitationChance: 90)
        XCTAssertTrue(SunsetScorer.score(sky, event: .sunrise).summary.contains("at sunrise"))
    }
}
