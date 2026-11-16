import Foundation

public enum Element: String, CaseIterable, Codable, Sendable {
    case wood = "木"
    case fire = "火"
    case earth = "土"
    case metal = "金"
    case water = "水"
}

public enum Stem: String, CaseIterable, Codable, Sendable {
    case jia = "甲", yi = "乙", bing = "丙", ding = "丁", wu = "戊"
    case ji = "己", geng = "庚", xin = "辛", ren = "壬", gui = "癸"

    public var text: String { rawValue }
    public var element: Element { Element.allCases[index / 2] }

    fileprivate var index: Int { Self.allCases.firstIndex(of: self)! }
}

public enum Branch: String, CaseIterable, Codable, Sendable {
    case zi = "子", chou = "丑", yin = "寅", mao = "卯", chen = "辰", si = "巳"
    case wu = "午", wei = "未", shen = "申", you = "酉", xu = "戌", hai = "亥"

    public var text: String { rawValue }

    public var element: Element {
        switch self {
        case .zi, .hai: .water
        case .yin, .mao: .wood
        case .si, .wu: .fire
        case .shen, .you: .metal
        case .chou, .chen, .wei, .xu: .earth
        }
    }

    /// 本气在首位，随后为中气和余气。
    public var hiddenStems: [Stem] {
        switch self {
        case .zi: [.gui]
        case .chou: [.ji, .gui, .xin]
        case .yin: [.jia, .bing, .wu]
        case .mao: [.yi]
        case .chen: [.wu, .yi, .gui]
        case .si: [.bing, .geng, .wu]
        case .wu: [.ding, .ji]
        case .wei: [.ji, .ding, .yi]
        case .shen: [.geng, .ren, .wu]
        case .you: [.xin]
        case .xu: [.wu, .xin, .ding]
        case .hai: [.ren, .jia]
        }
    }
}

public struct Pillar: Equatable, Codable, Sendable {
    public let stem: Stem
    public let branch: Branch

    public init(stem: Stem, branch: Branch) {
        self.stem = stem
        self.branch = branch
    }

    public var text: String { stem.text + branch.text }
}

public struct BirthInput: Equatable, Codable, Sendable {
    public let year: Int
    public let month: Int
    public let day: Int
    public let hour: Int
    public let minute: Int
    public let timeZoneID: String

    public init(year: Int, month: Int, day: Int, hour: Int, minute: Int, timeZoneID: String) {
        self.year = year
        self.month = month
        self.day = day
        self.hour = hour
        self.minute = minute
        self.timeZoneID = timeZoneID
    }
}

public struct BaziChart: Equatable, Codable, Sendable {
    public let year: Pillar
    public let month: Pillar
    public let day: Pillar
    public let hour: Pillar

    public init(year: Pillar, month: Pillar, day: Pillar, hour: Pillar) {
        self.year = year
        self.month = month
        self.day = day
        self.hour = hour
    }

    public var pillars: [Pillar] { [year, month, day, hour] }
}

public enum SolarTerm: String, CaseIterable, Codable, Sendable {
    case minorCold = "小寒", majorCold = "大寒", startOfSpring = "立春", rainWater = "雨水"
    case awakeningOfInsects = "惊蛰", springEquinox = "春分", pureBrightness = "清明", grainRain = "谷雨"
    case startOfSummer = "立夏", grainFull = "小满", grainInEar = "芒种", summerSolstice = "夏至"
    case minorHeat = "小暑", majorHeat = "大暑", startOfAutumn = "立秋", endOfHeat = "处暑"
    case whiteDew = "白露", autumnEquinox = "秋分", coldDew = "寒露", frostDescent = "霜降"
    case startOfWinter = "立冬", minorSnow = "小雪", majorSnow = "大雪", winterSolstice = "冬至"
}

public struct SolarTermOccurrence: Equatable, Sendable {
    public let term: SolarTerm
    public let date: Date
}

public enum BaziError: LocalizedError, Equatable, Sendable {
    case unsupportedYear
    case invalidDate
    case invalidTime
    case invalidTimeZone
    case unavailableCivilTime

    public var errorDescription: String? {
        switch self {
        case .unsupportedYear: "出生年份须在 1901 至 2099 年之间。"
        case .invalidDate: "请填写有效的公历出生日期。"
        case .invalidTime: "请填写 00:00 至 23:59 之间的出生时间。"
        case .invalidTimeZone: "请选择有效的出生地时区。"
        case .unavailableCivilTime: "该时区的这段本地时间因时钟调整而跳过，请核对出生时间或时区。"
        }
    }
}

public enum BaziCalculator {
    public static let supportedYears = 1901...2099

    private static let utc = TimeZone(secondsFromGMT: 0)!
    private static let utcCalendar = gregorian(in: utc)

    public static func chart(for birth: BirthInput) throws -> BaziChart {
        let (date, zone) = try resolve(birth)
        // Two solar boundaries operate on absolute instants: 立春 starts the year,
        // and the twelve 节 (alternating with 中气) each start a month.
        let spring = occurrence(year: birth.year, index: 2).date
        let solarYear = birth.year - (date < spring ? 1 : 0)
        let year = cyclicalPillar(solarYear - 1984)
        let utcYear = utcCalendar.component(.year, from: date)
        let (_, currentIndex) = currentTermIndex(at: date, utcYear: utcYear)
        // In the civil-year term sequence, 小寒 is the last solar month (丑).
        let monthOffset = (currentIndex / 2 + 11) % 12
        let monthStemIndex = (year.stem.index % 5 * 2 + 2 + monthOffset) % 10
        let month = Pillar(
            stem: Stem.allCases[monthStemIndex],
            branch: Branch.allCases[(2 + monthOffset) % 12]
        )

        // The civil date changes at 00:00. Both parts of 子时 use their own civil day's stem.
        let day = dayPillar(for: date, in: zone)
        let hourBranchIndex = ((birth.hour + 1) / 2) % 12
        let hourStemIndex = (day.stem.index % 5 * 2 + hourBranchIndex) % 10
        let hour = Pillar(stem: Stem.allCases[hourStemIndex], branch: Branch.allCases[hourBranchIndex])
        return BaziChart(year: year, month: month, day: day, hour: hour)
    }

    public static func dayPillar(for date: Date, in timeZone: TimeZone) -> Pillar {
        let localSeconds = date.timeIntervalSince1970 + Double(timeZone.secondsFromGMT(for: date))
        let julianDayNumber = Int(floor(localSeconds / 86_400)) + 2_440_588
        // Calendrical Calculations uses amod(Rata Die - 45, 60), numbered from 1.
        // With JDN = Rata Die + 1,721,425 this becomes (JDN + 49) mod 60, numbered from 0.
        return cyclicalPillar(julianDayNumber + 49)
    }

    public static func solarTerms(
        around date: Date, in timeZone: TimeZone = .current
    ) -> (current: SolarTermOccurrence, next: SolarTermOccurrence)? {
        let localDate = gregorian(in: timeZone).dateComponents([.era, .year], from: date)
        guard localDate.era == 1, let localYear = localDate.year,
              supportedYears.contains(localYear) else { return nil }
        let utcYear = utcCalendar.component(.year, from: date)
        let (year, index) = currentTermIndex(at: date, utcYear: utcYear)
        let lastTerm = SolarTerm.allCases.count - 1
        let next = index == lastTerm
            ? occurrence(year: year + 1, index: 0)
            : occurrence(year: year, index: index + 1)
        return (occurrence(year: year, index: index), next)
    }

    private static func gregorian(in timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    private static func resolve(_ birth: BirthInput) throws -> (Date, TimeZone) {
        guard supportedYears.contains(birth.year) else { throw BaziError.unsupportedYear }
        guard (1...12).contains(birth.month), (1...31).contains(birth.day) else {
            throw BaziError.invalidDate
        }
        guard (0...23).contains(birth.hour), (0...59).contains(birth.minute) else {
            throw BaziError.invalidTime
        }
        guard let zone = TimeZone(identifier: birth.timeZoneID) else { throw BaziError.invalidTimeZone }

        let components = DateComponents(
            year: birth.year, month: birth.month, day: birth.day,
            hour: birth.hour, minute: birth.minute, second: 0
        )
        let fields: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        guard let utcDate = utcCalendar.date(from: components),
              utcCalendar.dateComponents(fields, from: utcDate) == components else {
            throw BaziError.invalidDate
        }
        // The adjacent UTC days bracket the offsets that can apply to the birth time.
        // Round-trip each candidate using the full offset, including historical seconds.
        let offsets = Set([-86_400.0, 86_400.0].map { delta in
            zone.secondsFromGMT(for: utcDate.addingTimeInterval(delta))
        })
        let candidates = offsets.compactMap { offset -> Date? in
            let candidate = utcDate.addingTimeInterval(-Double(offset))
            return zone.secondsFromGMT(for: candidate) == offset ? candidate : nil
        }
        guard let date = candidates.min() else {
            throw BaziError.unavailableCivilTime
        }
        return (date, zone)
    }

    private static func cyclicalPillar(_ index: Int) -> Pillar {
        let cycleIndex = (index % 60 + 60) % 60
        return Pillar(stem: Stem.allCases[cycleIndex % 10], branch: Branch.allCases[cycleIndex % 12])
    }

    private static func currentTermIndex(at date: Date, utcYear: Int) -> (year: Int, index: Int) {
        let elapsed = date.timeIntervalSince(januaryFirst(of: utcYear))
        let seconds = SolarTermTable.secondsByYear[utcYear - SolarTermTable.firstYear]
        if let index = seconds.lastIndex(where: { Double($0) <= elapsed }) {
            return (utcYear, index)
        }
        return (utcYear - 1, SolarTerm.allCases.count - 1)
    }

    private static func occurrence(year: Int, index: Int) -> SolarTermOccurrence {
        let seconds = SolarTermTable.secondsByYear[year - SolarTermTable.firstYear][index]
        return SolarTermOccurrence(
            term: SolarTerm.allCases[index],
            date: januaryFirst(of: year).addingTimeInterval(Double(seconds))
        )
    }

    private static func januaryFirst(of year: Int) -> Date {
        utcCalendar.date(from: DateComponents(year: year, month: 1, day: 1))!
    }
}
