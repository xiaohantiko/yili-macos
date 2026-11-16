import SwiftUI
import YiLiCore

struct NatalPage: View {
    let profile: BirthProfile
    let edit: () -> Void

    var body: some View {
        let reading = Interpretation.natal(for: profile.chart)

        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .bottom) {
                PageTitle(title: "生辰命盘", index: "02  /  BIRTH CHART")
                Spacer()
                Button(profile.isSample ? "输入我的出生资料" : "编辑出生资料", action: edit)
                    .buttonStyle(OutlineButton())
                    .padding(.bottom, 4)
            }

            HStack(spacing: 10) {
                Image(systemName: "calendar")
                    .foregroundStyle(Ink.gold)
                Text(CivilDate.birthStamp(profile.birth))
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Ink.text)
                Text(TimeZoneCatalog.displayName(profile.birth.timeZoneID))
                    .foregroundStyle(Ink.secondary)
                if profile.isSample {
                    Text("体验")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Ink.goldLight)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Ink.gold.opacity(0.11), in: RoundedRectangle(cornerRadius: 4))
                }
            }
            .font(.system(size: 12))

            HStack(spacing: 12) {
                PillarCard(title: "年柱", index: "YEAR", pillar: profile.chart.year)
                PillarCard(title: "月柱", index: "MONTH", pillar: profile.chart.month)
                PillarCard(title: "日柱", index: "DAY", pillar: profile.chart.day, isDay: true)
                PillarCard(title: "时柱", index: "HOUR", pillar: profile.chart.hour)
            }

            SectionTitle(title: "五行分布", index: "FIVE ELEMENTS")
            ElementPanel(shares: reading.elements)

            SectionTitle(title: "命理解读", index: "DAY MASTER")
            VStack(alignment: .leading, spacing: 12) {
                Text(reading.headline)
                    .font(song(31))
                    .foregroundStyle(Ink.element(reading.dayMaster.element))
                Text(reading.summary)
                    .foregroundStyle(Ink.text)
                ForEach(reading.observations) { note in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(note.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Ink.goldLight)
                            .fixedSize()
                        Text(note.text)
                            .foregroundStyle(Ink.secondary)
                    }
                }
            }
            .font(.system(size: 13))
            .lineSpacing(4)
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(Panel())
        }
    }
}

private struct PillarCard: View {
    let title: String
    let index: String
    let pillar: Pillar
    var isDay = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Ink.text)
                Spacer(minLength: 2)
                IndexLabel(index)
                    .accessibilityHidden(true)
            }

            HStack(spacing: 8) {
                character(pillar.stem.text, element: pillar.stem.element, caption: "天干")
                Rectangle().fill(Ink.line).frame(width: 1, height: 39)
                character(pillar.branch.text, element: pillar.branch.element, caption: "地支")
            }

            Rectangle().fill(Ink.line).frame(height: 1)

            HStack(spacing: 5) {
                Text("藏干")
                    .foregroundStyle(Ink.quiet)
                ForEach(pillar.branch.hiddenStems, id: \.text) { stem in
                    Text(stem.text)
                        .foregroundStyle(Ink.element(stem.element))
                }
            }
            .font(.system(size: 11))
        }
        .padding(15)
        .frame(maxWidth: .infinity)
        .background(isDay ? Ink.color(0x27261d) : Ink.panel, in: RoundedRectangle(cornerRadius: 10))
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isDay ? Ink.goldLine : Ink.line, lineWidth: 1)
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .combine)
    }

    private func character(_ label: String, element: Element, caption: String) -> some View {
        VStack(spacing: 5) {
            Text(label)
                .font(song(37))
                .foregroundStyle(Ink.element(element))
            Text(caption + " · " + element.rawValue)
                .font(.system(size: 10))
                .foregroundStyle(Ink.quiet)
                .fixedSize()
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ElementPanel: View {
    let shares: [ElementShare]

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            GeometryReader { proxy in
                HStack(spacing: 0) {
                    ForEach(shares) { share in
                        Rectangle()
                            .fill(Ink.element(share.element))
                            .frame(width: proxy.size.width * share.fraction)
                    }
                }
                .clipShape(Capsule())
            }
            .frame(height: 8)
            .accessibilityHidden(true)

            HStack(spacing: 6) {
                ForEach(shares) { share in
                    HStack(spacing: 7) {
                        Circle()
                            .fill(Ink.element(share.element))
                            .frame(width: 6, height: 6)
                        Text(share.element.rawValue)
                            .foregroundStyle(Ink.text)
                        Text(share.fraction, format: .percent.precision(.fractionLength(0...2)))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(Ink.secondary)
                    }
                    .font(.system(size: 13, weight: .medium))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                }
            }

            Text("按四柱天干及地支藏干加权展示")
                .font(.system(size: 11))
                .foregroundStyle(Ink.quiet)
        }
        .padding(17)
        .modifier(Panel())
    }
}
