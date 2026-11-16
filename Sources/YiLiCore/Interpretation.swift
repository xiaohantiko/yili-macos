public struct ElementShare: Identifiable, Sendable {
    public var id: Element { element }
    public let element: Element
    public let weight: Double
    public let fraction: Double
}

public struct ReadingNote: Identifiable, Sendable {
    public var id: String { title }
    public let title: String
    public let text: String
}

public struct NatalReading: Sendable {
    public let dayMaster: Stem
    public let elements: [ElementShare]
    public let headline: String
    public let summary: String
    public let observations: [ReadingNote]
}

public struct DailyReading: Sendable {
    public let pillar: Pillar
    public let headline: String
    public let summary: String
    public let notes: [ReadingNote]
    public let favors: [String]
    public let easeBack: [String]
    public let trigram: Trigram
    public let basis: String
}

public enum Trigram: String, CaseIterable, Identifiable, Sendable {
    case kan = "坎", gen = "艮", zhen = "震", xun = "巽"
    case li = "离", kun = "坤", dui = "兑", qian = "乾"

    public var id: String { rawValue }
    public var name: String { rawValue }
    public var symbol: String { attributes.symbol }
    public var direction: String { attributes.direction }
    public var bearing: Int { attributes.bearing }
    public var image: String { attributes.image }
    public var element: Element { attributes.element }
    public var prompt: String { attributes.prompt }

    private var attributes: (
        symbol: String, direction: String, bearing: Int, image: String, element: Element, prompt: String
    ) {
        switch self {
        case .kan:
            ("☵", "正北", 0, "水", .water, "整理容易积压的物品，给桌面留一块空白。")
        case .gen:
            ("☶", "东北", 45, "山", .earth, "把随手乱放的小物归到固定位置，给一项杂事收个尾。")
        case .zhen:
            ("☳", "正东", 90, "雷", .wood, "清出一条顺畅的动线，迈出一件小事的第一步。")
        case .xun:
            ("☴", "东南", 135, "风", .wood, "天气合适时开窗通风，顺手整理窗边。")
        case .li:
            ("☲", "正南", 180, "火", .fire, "把阅读或书写的位置收拾明亮，集中处理一项任务。")
        case .kun:
            ("☷", "西南", 225, "地", .earth, "归置共享区域，给常用物留出取放方便的位置。")
        case .dui:
            ("☱", "正西", 270, "泽", .metal, "整理一处可坐下聊天的角落，给交流留点时间。")
        case .qian:
            ("☰", "西北", 315, "天", .metal, "清理文件和工具，把当天的重点放在显眼处。")
        }
    }

    // The app pairs the branch's element with a later-heaven trigram.
    fileprivate init(branch: Branch) {
        switch branch {
        case .zi, .hai: self = .kan
        case .chen, .xu: self = .gen
        case .yin: self = .zhen
        case .mao: self = .xun
        case .si, .wu: self = .li
        case .chou, .wei: self = .kun
        case .you: self = .dui
        case .shen: self = .qian
        }
    }
}

public enum Interpretation {
    public static let natalMethod = """
        取日柱天干为日主。每柱天干计 1，地支藏干合计 1。一个藏干计 1，两个依次计 0.7、0.3，三个依次计 0.6、0.3、0.1。百分比展示本应用的五行分布。传统旺衰与用神须结合月令、格局等另行分析。
        """

    public static let dailyMethod = """
        比较流日天干与本命日主的五行生克，得到行动主题。本应用按流日地支取卦，子亥取坎、辰戌取艮、寅取震、卯取巽、巳午取离、丑未取坤、酉取兑、申取乾。卦象和后天方位用于象征性的空间整理提示。
        """

    public static func natal(for chart: BaziChart) -> NatalReading {
        let dayMaster = chart.day.stem
        let profile = dayMasterProfile(dayMaster)
        let elements = elementShares(in: chart)
        let maxWeight = elements.map(\.weight).max() ?? 0
        let leading = elements.filter { $0.weight == maxWeight }
        let leadingNames = leading.map { $0.element.rawValue }.joined(separator: "、")
        let distribution: String
        if leading.count == elements.count {
            distribution = "五行权重相同。可以逐一对照五行的意象，选出最贴近近期处境的一项。"
        } else {
            let percent = Int(((leading.first?.fraction ?? 0) * 100).rounded())
            let description = leading.count == 1 ? "占比最高，约 \(percent)%" : "并列最高，各约 \(percent)%"
            distribution = "\(leadingNames)\(description)。这一分布综合了四柱天干与地支藏干。"
        }

        return NatalReading(
            dayMaster: dayMaster,
            elements: elements,
            headline: "\(dayMaster.text)\(dayMaster.element.rawValue)日主",
            summary: profile,
            observations: [
                ReadingNote(title: "五行分布", text: distribution),
                ReadingNote(
                    title: "出生时节",
                    text: "月柱为\(chart.month.text)，月支\(chart.month.branch.text)属\(chart.month.branch.element.rawValue)。传统子平法以月令作为观察出生时节的重要线索。"
                )
            ]
        )
    }

    public static func daily(for chart: BaziChart, day: Pillar) -> DailyReading {
        let dayMaster = chart.day.stem
        let relationship = FlowRelationship(natal: dayMaster.element, flow: day.stem.element)
        let guidance = relationship.guidance
        let trigram = Trigram(branch: day.branch)
        let natalName = dayMaster.text + dayMaster.element.rawValue
        let flowName = day.stem.text + day.stem.element.rawValue
        let relation = relationship.description(natal: natalName, flow: flowName)
        let branchElement = day.branch.element
        let natalShare = elementShares(in: chart).first { $0.element == branchElement }?.fraction ?? 0
        let natalPercent = Int((natalShare * 100).rounded())

        return DailyReading(
            pillar: day,
            headline: guidance.headline,
            summary: guidance.summary,
            notes: [
                ReadingNote(title: "工作与学习", text: guidance.work),
                ReadingNote(title: "人际与沟通", text: guidance.relationships),
                ReadingNote(title: "生活节奏", text: pace(for: branchElement))
            ],
            favors: guidance.favors,
            easeBack: guidance.easeBack,
            trigram: trigram,
            basis: "\(relation)。流日地支\(day.branch.text)属\(branchElement.rawValue)，此五行在本命中约占 \(natalPercent)%。取\(trigram.name)卦，后天方位为\(trigram.direction)。"
        )
    }

    private static func elementShares(in chart: BaziChart) -> [ElementShare] {
        var weights: [Element: Int] = [:]
        for pillar in chart.pillars {
            weights[pillar.stem.element, default: 0] += 10
            let hiddenStems = pillar.branch.hiddenStems
            let hiddenWeights: [Int]
            switch hiddenStems.count {
            case 1: hiddenWeights = [10]
            case 2: hiddenWeights = [7, 3]
            default: hiddenWeights = [6, 3, 1]
            }
            for (stem, weight) in zip(hiddenStems, hiddenWeights) {
                weights[stem.element, default: 0] += weight
            }
        }
        let total = Double(chart.pillars.count * 20)
        return Element.allCases.map { element in
            let weight = Double(weights[element, default: 0])
            return ElementShare(element: element, weight: weight / 10, fraction: weight / total)
        }
    }

    private static func dayMasterProfile(_ stem: Stem) -> String {
        switch stem {
        case .jia:
            "借甲木向上生长的意象，观察自己如何推进长线目标。选一件想做深的事，给它固定的时间，再允许做法随反馈调整。"
        case .yi:
            "借乙木顺势伸展的意象，观察自己如何在变化中找空间。卡住时，可以先换一种问法或找一位能互补的同伴。"
        case .bing:
            "借丙火照亮四方的意象，观察自己如何分享想法、带动讨论。表达之后留一点停顿，让他人的想法也有机会展开。"
        case .ding:
            "借丁火照见近处的意象，观察自己如何照顾细节。给一件值得用心的事留下完整时间，再决定哪些细节可以放手。"
        case .wu:
            "借戊土承托的意象，观察自己如何建立稳固的安排。明确一项最重要的责任，也给计划留出随情况调整的余地。"
        case .ji:
            "借己土培育的意象，观察自己如何把零散资源变成长期积累。把照顾他人的时间和自己的恢复时间一起写进日程。"
        case .geng:
            "借庚金成器的意象，观察自己如何取舍和执行。先说清选择的标准，再用一次小范围试行验证它。"
        case .xin:
            "借辛金琢磨的意象，观察自己如何打磨品质。给每次修订设一个完成标准，留时间收集真实反馈。"
        case .ren:
            "借壬水流动的意象，观察自己如何应对变化。备好另一条路径，也选一件值得持续投入的事作为主线。"
        case .gui:
            "借癸水浸润的意象，观察自己如何从细节收集信息。先写下观察，再用一个小行动验证判断。"
        }
    }

    private static func pace(for element: Element) -> String {
        switch element {
        case .wood: "给一件新事留二十分钟试做，结束时记下下一步。"
        case .fire: "把需要集中表达的事情安排在一个时段，前后各留一点安静时间。"
        case .earth: "先照顾吃饭、休息和出门准备，再安排可选的活动。"
        case .metal: "删去一项低优先级安排，集中整理需要带走或交付的东西。"
        case .water: "在紧凑的安排之间留一个空档，散步或记下今天的感受。"
        }
    }
}

private enum FlowRelationship {
    case sameElement
    case supportsNatal
    case expressesNatal
    case directedByNatal
    case checksNatal

    init(natal: Element, flow: Element) {
        if natal == flow {
            self = .sameElement
        } else if flow.generates == natal {
            self = .supportsNatal
        } else if natal.generates == flow {
            self = .expressesNatal
        } else if natal.controls == flow {
            self = .directedByNatal
        } else {
            self = .checksNatal
        }
    }

    func description(natal: String, flow: String) -> String {
        switch self {
        case .sameElement: "流日天干\(flow)与本命日主\(natal)同属一行"
        case .supportsNatal: "流日天干\(flow)生本命日主\(natal)"
        case .expressesNatal: "本命日主\(natal)生流日天干\(flow)"
        case .directedByNatal: "本命日主\(natal)克流日天干\(flow)"
        case .checksNatal: "流日天干\(flow)克本命日主\(natal)"
        }
    }

    var guidance: (
        headline: String, summary: String, work: String, relationships: String,
        favors: [String], easeBack: [String]
    ) {
        switch self {
        case .sameElement:
            (
                "借熟悉的节奏推进",
                "把精力放到一个已经摸清方向的目标上，顺手和同行的人对齐进度。",
                "选一项有积累的任务，定下今天能交付的部分，再安排后续。",
                "和熟悉的人交换近况，合作前说清各自负责的部分。",
                ["推进手头重点", "和伙伴对齐进度"],
                ["同时开启多个任务", "比较彼此的进度"]
            )
        case .supportsNatal:
            (
                "先吸收，再行动",
                "留一段时间整理信息或请教，把获得的帮助转成能立刻做的一小步。",
                "把卡点写成一个具体问题，找资料或请教有经验的人。",
                "听完再复述对方的重点，确认理解后再回应。",
                ["请教与整理笔记", "复盘近期经验"],
                ["资料未齐就定方案", "把日程排得太满"]
            )
        case .expressesNatal:
            (
                "把想法做成草稿",
                "用一份能看见、能讨论的初稿，把脑海里的想法往前推一步。",
                "给写作、制作或展示划出一段完整时间，先做一个可评议的版本。",
                "说出一个具体想法或感受，并问问对方接收到了什么。",
                ["写初稿或做原型", "分享阶段成果"],
                ["过早反复润色", "一次说太多重点"]
            )
        case .directedByNatal:
            (
                "收拢目标，落实一件",
                "用清晰的完成条件把零散事务归拢起来，优先做可确认的一件。",
                "选一项积压任务，写出完成标准，按步骤处理并确认结果。",
                "把请求、时间和分工说清楚，留出让对方回应的空间。",
                ["清理待办", "确认分工与时限"],
                ["临时增加承诺", "替他人作决定"]
            )
        case .checksNatal:
            (
                "先理清边界",
                "遇到规则、时限或分歧时，先弄清条件，再选一个能控制的动作。",
                "先确认规则、依赖和期限，做完一段就检查一次。",
                "分歧时先确认事实与各自需要，把后续行动约具体。",
                ["校对关键细节", "预留调整时间"],
                ["匆忙作出承诺", "在情绪最强时争辩"]
            )
        }
    }
}

private extension Element {
    var generates: Element {
        switch self {
        case .wood: .fire
        case .fire: .earth
        case .earth: .metal
        case .metal: .water
        case .water: .wood
        }
    }

    var controls: Element {
        switch self {
        case .wood: .earth
        case .fire: .metal
        case .earth: .water
        case .metal: .wood
        case .water: .fire
        }
    }
}
