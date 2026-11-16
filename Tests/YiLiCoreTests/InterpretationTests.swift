import Testing
import YiLiCore

struct InterpretationTests {
    private let chart = BaziChart(
        year: Pillar(stem: .ji, branch: .mao),
        month: Pillar(stem: .ding, branch: .chou),
        day: Pillar(stem: .jia, branch: .zi),
        hour: Pillar(stem: .geng, branch: .wu)
    )

    @Test func fiveElementSharesIncludeHiddenStems() {
        let reading = Interpretation.natal(for: chart)

        #expect(reading.dayMaster == .jia)
        #expect(reading.elements.map(\.element) == [.wood, .fire, .earth, .metal, .water])
        #expect(reading.elements.map(\.weight) == [2, 1.7, 1.9, 1.1, 1.3])
        #expect(abs(reading.elements.reduce(0) { $0 + $1.fraction } - 1) < 0.0001)
    }

    @Test func dailyGuidanceDistinguishesAllFiveFlowRelationships() {
        let samples: [(day: Pillar, relation: String, trigram: Trigram)] = [
            (Pillar(stem: .jia, branch: .zi), "甲木与本命日主甲木同属一行", .kan),
            (Pillar(stem: .ren, branch: .shen), "壬水生本命日主甲木", .qian),
            (Pillar(stem: .bing, branch: .yin), "甲木生流日天干丙火", .zhen),
            (Pillar(stem: .wu, branch: .chen), "甲木克流日天干戊土", .gen),
            (Pillar(stem: .geng, branch: .wu), "庚金克本命日主甲木", .li),
        ]

        let headlines = samples.map { sample in
            let reading = Interpretation.daily(for: chart, day: sample.day)
            #expect(reading.pillar == sample.day)
            #expect(reading.basis.contains(sample.relation))
            #expect(reading.trigram == sample.trigram)
            return reading.headline
        }
        #expect(Set(headlines).count == samples.count)
    }

    @Test func branchTrigramsKeepTheirFiveElementAssociation() {
        let trigrams = Branch.allCases.map { branch in
            let reading = Interpretation.daily(for: chart, day: Pillar(stem: .jia, branch: branch))
            #expect(reading.trigram.element == branch.element)
            return reading.trigram
        }

        #expect(Set(trigrams) == Set(Trigram.allCases))
    }
}
