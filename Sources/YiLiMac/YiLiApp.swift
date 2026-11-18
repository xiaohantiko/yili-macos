import Combine
import SwiftUI
import YiLiCore

// Select the SwiftUI property wrapper on SDKs that also declare a State macro.
typealias StateProperty<Value> = SwiftUI.State<Value>

@main
struct YiLiApp: App {
    var body: some Scene {
        Window("易历", id: "almanac") {
            AlmanacWindow()
                .frame(minWidth: 980, minHeight: 650)
                .preferredColorScheme(.dark)
        }
        .defaultSize(width: 1180, height: 820)
        .windowResizability(.contentMinSize)
        .windowStyle(.hiddenTitleBar)
    }
}

struct AlmanacWindow: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateProperty private var store = BirthStore()
    @StateProperty private var gpt = GPTSession()
    @StateProperty private var page: AlmanacPage = .daily
    @StateProperty private var editing = false
    @StateProperty private var now = Date()
    @StateProperty private var previewDate: Date?

    private let clock = Timer.publish(every: 15, on: .main, in: .common).autoconnect()

    private var calendar: Calendar { CivilDate.calendar(in: .autoupdatingCurrent) }
    private var displayDate: Date { previewDate ?? now }
    private var showingToday: Bool { calendar.isDate(displayDate, inSameDayAs: now) }

    var body: some View {
        HStack(spacing: 0) {
            Sidebar(page: $page, profile: store.profile) { editing = true }
                .frame(width: 202)
            Rectangle()
                .fill(Ink.line)
                .frame(width: 1)
            ScrollView {
                Group {
                    if let profile = store.profile {
                        switch page {
                        case .daily:
                            DailyPage(
                                profile: profile, date: displayDate, now: now,
                                gpt: gpt,
                                timeZone: calendar.timeZone, isToday: showingToday,
                                move: moveDay, returnToToday: { previewDate = nil },
                                edit: { editing = true }
                            )
                        case .natal:
                            NatalPage(profile: profile) { editing = true }
                        case .methods:
                            MethodsPage()
                        }
                    } else {
                        ContentUnavailableView {
                            Label("建立命盘", systemImage: "calendar")
                        } description: {
                            Text("输入出生时间后开始排盘。")
                        } actions: {
                            Button("输入出生资料") { editing = true }
                                .buttonStyle(GoldButton())
                        }
                        .padding(.vertical, 70)
                    }
                }
                .frame(maxWidth: 1080)
                .padding(.horizontal, 38)
                .padding(.top, 48)
                .padding(.bottom, 34)
                .frame(maxWidth: .infinity)
                .id(page)
            }
            .background(Ink.background)
            .defaultScrollAnchor(.top)
        }
        .background(Ink.background)
        .sheet(isPresented: $editing) {
            BirthEditor(
                birth: store.profile?.birth ?? BirthStore.sample,
                isSample: store.profile?.isSample ?? true,
                save: { birth in
                    try store.save(birth)
                    page = .natal
                },
                reset: store.reset
            )
        }
        .onReceive(clock) { now = $0 }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { now = Date() }
        }
        .onChange(of: store.profile?.birth) { _, _ in gpt.invalidate() }
    }

    private func moveDay(_ direction: Int) {
        let day = calendar.startOfDay(for: displayDate)
        guard let next = calendar.date(byAdding: .day, value: direction, to: day) else { return }
        previewDate = calendar.isDate(next, inSameDayAs: now) ? nil : next
    }
}

enum AlmanacPage: Hashable {
    case daily, natal, methods

    var title: String {
        switch self {
        case .daily: "今日运势"
        case .natal: "生辰命盘"
        case .methods: "排盘说明"
        }
    }

    var icon: String {
        switch self {
        case .daily: "sun.horizon"
        case .natal: "square.grid.2x2"
        case .methods: "book.closed"
        }
    }
}

struct BirthProfile {
    let birth: BirthInput
    let chart: BaziChart
    let isSample: Bool
}

@MainActor @Observable
final class BirthStore {
    static let sample = BirthInput(
        year: 1990, month: 5, day: 17, hour: 10, minute: 30,
        timeZoneID: "Asia/Shanghai"
    )

    private static let storageKey = "localBirthProfile.v1"
    private(set) var profile: BirthProfile?

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let birth = try? JSONDecoder().decode(BirthInput.self, from: data),
           let chart = try? BaziCalculator.chart(for: birth) {
            profile = BirthProfile(birth: birth, chart: chart, isSample: false)
        } else {
            try? reset()
        }
    }

    func save(_ birth: BirthInput) throws {
        let chart = try BaziCalculator.chart(for: birth)
        let data = try JSONEncoder().encode(birth)
        UserDefaults.standard.set(data, forKey: Self.storageKey)
        profile = BirthProfile(birth: birth, chart: chart, isSample: false)
    }

    func reset() throws {
        let chart = try BaziCalculator.chart(for: Self.sample)
        UserDefaults.standard.removeObject(forKey: Self.storageKey)
        profile = BirthProfile(birth: Self.sample, chart: chart, isSample: true)
    }
}

enum CivilDate {
    static func calendar(in timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }

    static func formatted(_ date: Date, pattern: String, in timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.calendar = calendar(in: timeZone)
        formatter.timeZone = timeZone
        formatter.dateFormat = pattern
        return formatter.string(from: date)
    }

    static func birthStamp(_ birth: BirthInput) -> String {
        String(format: "%04d.%02d.%02d  ·  %02d:%02d", birth.year, birth.month, birth.day, birth.hour, birth.minute)
    }
}
