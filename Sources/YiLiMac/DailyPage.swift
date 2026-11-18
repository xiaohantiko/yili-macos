import SwiftUI
import YiLiCore

struct DailyPage: View {
    let profile: BirthProfile
    let date: Date
    let now: Date
    let gpt: GPTSession
    let timeZone: TimeZone
    let isToday: Bool
    let move: (Int) -> Void
    let returnToToday: () -> Void
    let edit: () -> Void

    private var dateTitle: String { CivilDate.formatted(date, pattern: "yyyy.MM.dd", in: timeZone) }
    private var weekday: String { CivilDate.formatted(date, pattern: "EEEE", in: timeZone) }

    var body: some View {
        let pillar = BaziCalculator.dayPillar(for: date, in: timeZone)
        let reading = Interpretation.daily(for: profile.chart, day: pillar)
        let calendar = CivilDate.calendar(in: timeZone)
        let termDate = isToday ? now : (calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date)
        let term = BaziCalculator.solarTerms(around: termDate, in: timeZone)?.current.term.rawValue

        VStack(alignment: .leading, spacing: 23) {
            HStack(alignment: .bottom) {
                PageTitle(title: isToday ? "今日运势" : "每日运势", index: "01  /  DAILY ALMANAC")
                Spacer()
                if profile.isSample {
                    Button("输入我的出生资料", action: edit)
                        .buttonStyle(OutlineButton())
                        .padding(.trailing, 12)
                        .padding(.bottom, 4)
                }
                dateControls
            }

            dailyHero(reading, term: term)

            GPTPanel(
                facts: GPTFacts.make(chart: profile.chart, date: date, termDate: termDate, timeZone: timeZone),
                session: gpt
            )

            HStack(alignment: .top, spacing: 14) {
                ActionCard(title: "宜做", icon: "arrow.up.right", items: reading.favors, color: Ink.goldLight)
                ActionCard(title: "可缓", icon: "pause", items: reading.easeBack, color: Ink.quiet)
            }

            SectionTitle(title: "生活指引", index: "DAILY NOTES")
                .padding(.top, 2)

            HStack(alignment: .top, spacing: 12) {
                ForEach(reading.notes) { note in
                    VStack(alignment: .leading, spacing: 9) {
                        Text(note.title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Ink.text)
                        Text(note.text)
                            .font(.system(size: 13))
                            .foregroundStyle(Ink.secondary)
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .modifier(Panel(radius: 10))
                }
            }

            Text(reading.basis)
                .font(.system(size: 11))
                .foregroundStyle(Ink.quiet)
                .lineSpacing(3)
        }
    }

    private var dateControls: some View {
        VStack(alignment: .trailing, spacing: 8) {
            HStack(spacing: 7) {
                if !isToday {
                    Button("回到今天", action: returnToToday)
                        .buttonStyle(OutlineButton())
                }
                Text(dateTitle)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(Ink.text)
                HStack(spacing: 0) {
                    dayButton("chevron.left", label: "前一天", delta: -1)
                    Rectangle().fill(Ink.line).frame(width: 1, height: 16)
                    dayButton("chevron.right", label: "后一天", delta: 1)
                }
                .modifier(Panel(radius: 6))
            }
            Text(weekday)
                .font(.system(size: 11))
                .foregroundStyle(Ink.quiet)
        }
        .padding(.bottom, 3)
    }

    private func dayButton(_ icon: String, label: String, delta: Int) -> some View {
        Button {
            move(delta)
        } label: {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Ink.goldLight)
                .frame(width: 28, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }

    private func dailyHero(_ reading: DailyReading, term: String?) -> some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    badge(reading.pillar.text + "日", icon: "calendar")
                    if let term { badge(term, icon: "leaf") }
                }
                Spacer(minLength: 18)
                Text(reading.headline)
                    .font(song(37))
                    .foregroundStyle(Ink.text)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Text(reading.summary)
                    .font(.system(size: 14))
                    .foregroundStyle(Ink.secondary)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
                Spacer(minLength: 18)
                Rectangle()
                    .fill(Ink.goldLine)
                    .frame(height: 1)
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "location.north.line")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Ink.gold)
                        .padding(.top, 2)
                    Text(reading.trigram.prompt)
                        .font(.system(size: 12))
                        .foregroundStyle(Ink.secondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 11)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(26)

            VStack(spacing: 6) {
                BaguaDial(active: reading.trigram)
                    .frame(width: 232, height: 232)
                    .accessibilityHidden(true)
                Text("\(reading.trigram.name)卦 · \(reading.trigram.image) · \(reading.trigram.direction)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Ink.goldLight)
                    .accessibilityLabel("后天八卦，\(reading.trigram.name)卦，\(reading.trigram.image)，\(reading.trigram.direction)")
                IndexLabel("BAGUA  /  后天八卦")
                    .accessibilityHidden(true)
            }
            .frame(width: 302)
            .padding(.vertical, 15)
        }
        .frame(minHeight: 305)
        .background {
            RoundedRectangle(cornerRadius: 15)
                .fill(LinearGradient(
                    colors: [Ink.color(0x26261c), Ink.color(0x1c201a), Ink.color(0x21241b)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 15)
                .strokeBorder(Ink.goldLine, lineWidth: 1)
                .allowsHitTesting(false)
        }
    }

    private func badge(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(Ink.goldLight)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Ink.gold.opacity(0.08), in: RoundedRectangle(cornerRadius: 5))
            .overlay {
                RoundedRectangle(cornerRadius: 5).strokeBorder(Ink.goldLine, lineWidth: 1)
            }
    }
}

private struct ActionCard: View {
    let title: String
    let icon: String
    let items: [String]
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(color)
                    .frame(width: 23, height: 23)
                    .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 5))
                    .accessibilityHidden(true)
                Text(title)
                    .font(song(21))
                    .foregroundStyle(Ink.text)
                    .accessibilityAddTraits(.isHeader)
            }
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(color.opacity(0.8))
                        .frame(width: 3, height: 3)
                        .padding(.top, 7)
                    Text(item)
                        .font(.system(size: 13))
                        .foregroundStyle(Ink.secondary)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.horizontal, 17)
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
        .modifier(Panel(radius: 11))
    }
}

private struct BaguaDial: View {
    let active: Trigram

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2

            func point(_ bearing: Double, _ distance: Double) -> CGPoint {
                let angle = bearing * .pi / 180
                return CGPoint(x: center.x + sin(angle) * distance, y: center.y - cos(angle) * distance)
            }

            func line(_ start: CGPoint, _ end: CGPoint, _ color: Color, width: CGFloat = 1) {
                var path = Path()
                path.move(to: start)
                path.addLine(to: end)
                context.stroke(path, with: .color(color), lineWidth: width)
            }

            for scale in [0.99, 0.91, 0.69, 0.47, 0.37] {
                let r = radius * scale
                let ring = CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
                context.stroke(Path(ellipseIn: ring), with: .color(Ink.gold.opacity(scale == 0.91 ? 0.38 : 0.19)), lineWidth: 0.75)
            }

            for tick in 0..<72 {
                let bearing = Double(tick) * 5
                let major = tick.isMultiple(of: 9)
                line(
                    point(bearing, radius * (major ? 0.922 : 0.953)),
                    point(bearing, radius * 0.978),
                    Ink.gold.opacity(major ? 0.68 : 0.27),
                    width: major ? 1.1 : 0.6
                )
            }

            for trigram in Trigram.allCases {
                let angle = Double(trigram.bearing)
                let on = trigram.name == active.name
                line(point(angle + 22.5, radius * 0.47), point(angle + 22.5, radius * 0.90), Ink.gold.opacity(0.18), width: 0.7)
                if on {
                    var arc = Path()
                    arc.addArc(center: center, radius: radius * 0.91, startAngle: .degrees(angle - 106), endAngle: .degrees(angle - 74), clockwise: false)
                    context.stroke(arc, with: .color(Ink.goldLight), lineWidth: 1.8)
                }
                context.draw(
                    Text(trigram.name).font(song(16)).foregroundStyle(on ? Ink.goldLight : Ink.quiet),
                    at: point(angle, radius * 0.805)
                )
                drawBars(trigram, at: point(angle, radius * 0.58), width: 15, color: on ? Ink.goldLight : Ink.gold.opacity(0.45), context: context)
            }

            drawBars(active, at: CGPoint(x: center.x, y: center.y - 7), width: 37, color: Ink.goldLight, context: context)
            context.draw(
                Text(active.direction).font(.system(size: 10, weight: .medium)).foregroundStyle(Ink.gold),
                at: CGPoint(x: center.x, y: center.y + 20)
            )
        }
    }

    private func drawBars(_ trigram: Trigram, at center: CGPoint, width: CGFloat, color: Color, context: GraphicsContext) {
        let solidRows: [[Bool]] = [
            [false, true, false], [true, false, false], [false, false, true], [true, true, false],
            [true, false, true], [false, false, false], [false, true, true], [true, true, true]
        ]
        let bearingIndex = Int(trigram.bearing) / 45
        let pitch = width / 4.6
        let thickness = width / 13
        for (row, solid) in solidRows[bearingIndex].enumerated() {
            let y = center.y + CGFloat(row - 1) * pitch - thickness / 2
            let left = center.x - width / 2
            if solid {
                context.fill(Path(CGRect(x: left, y: y, width: width, height: thickness)), with: .color(color))
            } else {
                let bar = width * 0.41
                context.fill(Path(CGRect(x: left, y: y, width: bar, height: thickness)), with: .color(color))
                context.fill(Path(CGRect(x: left + width - bar, y: y, width: bar, height: thickness)), with: .color(color))
            }
        }
    }
}
