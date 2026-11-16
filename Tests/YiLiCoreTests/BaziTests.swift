import Foundation
import Testing
@testable import YiLiCore

struct BaziTests {
    @Test func springCrossingChangesYearAndMonthAtTheSameInstant() throws {
        // 2024 HKO and CWA almanacs list 立春 at 16:27 UTC+8 to the nearest minute.
        let before = try BaziCalculator.chart(for: birth(2024, 2, 4, 16, 26))
        let after = try BaziCalculator.chart(for: birth(2024, 2, 4, 16, 28))
        #expect(before.pillars.map(\.text) == ["癸卯", "乙丑", "戊戌", "庚申"])
        #expect(after.pillars.map(\.text) == ["甲辰", "丙寅", "戊戌", "庚申"])

        let timeInNewYork = birth(2024, 2, 4, 3, 28, zone: "America/New_York")
        #expect(try BaziCalculator.chart(for: timeInNewYork).year == after.year)
        #expect(try BaziCalculator.chart(for: timeInNewYork).month == after.month)
    }

    @Test func jieChangesTheMonthAndZhongqiDoesNot() throws {
        let beforeRain = try BaziCalculator.chart(for: birth(2024, 2, 19, 12, 12))
        let afterRain = try BaziCalculator.chart(for: birth(2024, 2, 19, 12, 14))
        #expect(beforeRain.month.text == "丙寅")
        #expect(afterRain.month == beforeRain.month)

        let beforeJie = try BaziCalculator.chart(for: birth(2024, 3, 5, 10, 22))
        let afterJie = try BaziCalculator.chart(for: birth(2024, 3, 5, 10, 24))
        #expect(beforeJie.month.text == "丙寅")
        #expect(afterJie.month.text == "丁卯")
        #expect(beforeJie.year == afterJie.year)
    }

    @Test func civilDayChangesAtMidnightAndZiHourStartsAtTwentyThree() throws {
        let beforeZi = try BaziCalculator.chart(for: birth(2000, 1, 7, 22, 59))
        let ziEvening = try BaziCalculator.chart(for: birth(2000, 1, 7, 23, 0))
        let ziMorning = try BaziCalculator.chart(for: birth(2000, 1, 8, 0, 0))
        #expect(beforeZi.hour.text == "乙亥")
        #expect(ziEvening.day.text == "甲子")
        #expect(ziEvening.hour.text == "甲子")
        #expect(ziMorning.day.text == "乙丑")
        #expect(ziMorning.hour.text == "丙子")
    }

    @Test func dateRangesAndInvalidCivilInput() throws {
        let early = try BaziCalculator.chart(for: birth(1901, 1, 1, 0, 0))
        let late = try BaziCalculator.chart(for: birth(2099, 12, 31, 23, 59, zone: "America/New_York"))
        #expect(early.pillars.prefix(3).map(\.text) == ["庚子", "戊子", "己卯"])
        #expect(late.day.text == "壬寅")

        let leapDay = try BaziCalculator.chart(for: birth(2024, 2, 29, 12, 0))
        #expect(leapDay.day.text == "癸亥")
        #expect(throws: BaziError.unsupportedYear) {
            try BaziCalculator.chart(for: birth(1900, 1, 1, 0, 0))
        }
        #expect(throws: BaziError.invalidDate) {
            try BaziCalculator.chart(for: birth(2023, 2, 29, 12, 0))
        }
        #expect(throws: BaziError.invalidTime) {
            try BaziCalculator.chart(for: birth(2024, 2, 29, 24, 0))
        }
        #expect(throws: BaziError.invalidTimeZone) {
            try BaziCalculator.chart(for: birth(2024, 2, 29, 23, 0, zone: "Invalid/Zone"))
        }
        #expect(throws: BaziError.unavailableCivilTime) {
            try BaziCalculator.chart(for: birth(2024, 3, 10, 2, 30, zone: "America/Los_Angeles"))
        }
        #expect(throws: BaziError.unavailableCivilTime) {
            try BaziCalculator.chart(for: birth(2011, 12, 30, 12, 0, zone: "Pacific/Apia"))
        }
    }

    @Test func dayPillarUsesTheRequestedZonesDate() throws {
        let instant = try #require(ISO8601DateFormatter().date(from: "2024-02-04T16:30:00Z"))
        let shanghai = try #require(TimeZone(identifier: "Asia/Shanghai"))
        let newYork = try #require(TimeZone(identifier: "America/New_York"))
        #expect(BaziCalculator.dayPillar(for: instant, in: shanghai).text == "己亥")
        #expect(BaziCalculator.dayPillar(for: instant, in: newYork).text == "戊戌")
    }

    @Test func repeatedClockTimeSelectsTheEarlierInstant() throws {
        // The 2021 立冬 crossing at 04:58 UTC falls between the two 01:30s in Halifax.
        let local = try BaziCalculator.chart(for: birth(2021, 11, 7, 1, 30, zone: "America/Halifax"))
        let early = try BaziCalculator.chart(for: birth(2021, 11, 7, 4, 30, zone: "Etc/UTC"))
        let late = try BaziCalculator.chart(for: birth(2021, 11, 7, 5, 30, zone: "Etc/UTC"))
        #expect(early.month.text == "戊戌")
        #expect(late.month.text == "己亥")
        #expect(local.month == early.month)
    }

    @Test func birthTimePreservesHistoricalOffsetSeconds() throws {
        // Kathmandu was UTC+05:41:16. 17:21 there was 7 seconds before 立春.
        let before = try BaziCalculator.chart(for: birth(1901, 2, 4, 17, 21, zone: "Asia/Kathmandu"))
        let after = try BaziCalculator.chart(for: birth(1901, 2, 4, 17, 22, zone: "Asia/Kathmandu"))
        #expect(before.year.text == "庚子")
        #expect(after.year.text == "辛丑")
    }

    @Test func solarTermLookupIncludesTheNextYearsFirstTerm() throws {
        let instant = try #require(ISO8601DateFormatter().date(from: "2024-12-31T20:00:00Z"))
        let terms = try #require(BaziCalculator.solarTerms(around: instant))
        let publishedWinterSolstice = try #require(
            ISO8601DateFormatter().date(from: "2024-12-21T09:21:00Z")
        )
        #expect(terms.current.term == .winterSolstice)
        #expect(abs(terms.current.date.timeIntervalSince(publishedWinterSolstice)) < 31)
        #expect(terms.next.term == .minorCold)
        #expect(terms.current.date < instant)
        #expect(instant < terms.next.date)
        #expect(BaziCalculator.solarTerms(around: terms.next.date)?.current == terms.next)
    }

    private func birth(
        _ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int, zone: String = "Asia/Shanghai"
    ) -> BirthInput {
        BirthInput(year: year, month: month, day: day, hour: hour, minute: minute, timeZoneID: zone)
    }
}
