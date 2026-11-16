import SwiftUI
import YiLiCore

struct MethodsPage: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            PageTitle(title: "排盘说明", index: "03  /  METHODS")

            Text("易历将历法计算和传统文化解读分开展示。命理、宜忌和方位提示供日常反思与娱乐。")
                .font(.system(size: 14))
                .foregroundStyle(Ink.secondary)
                .lineSpacing(4)

            method("四柱如何排出", icon: "calendar") {
                let years = BaziCalculator.supportedYears
                let range = "\(years.lowerBound)–\(years.upperBound)"
                Text("输入 \(range) 年的公历出生日期、钟表时间和出生时区。时区采用当地历史时差与夏令时，重复出现的时刻取第一次。")
                Text("年柱于立春换年，月柱于十二个「节」交节时切换。节气表依据 JPL DE440 星历预先计算，以 UT1 近似民用时间。输入时间按所填分钟的起点处理。")
                Text("日柱在出生地的民用午夜切换。子时从 23:00 开始，时干取当时所属民用日的日干。")
            }

            method("五行如何计数", icon: "chart.bar.xaxis") {
                Text(Interpretation.natalMethod)
            }

            method("每日运势与风水提示", icon: "safari") {
                Text(Interpretation.dailyMethod)
                Text("日运日期按这台 Mac 的本地时区划分。今日显示当前节气，前后日期显示当地正午所在的节气。")
            }

            method("出生资料与离线使用", icon: "lock") {
                Text("出生资料仅保存在这台 Mac。排盘、解读和日运均可离线使用。可在出生资料窗口清除已保存的资料，回到体验命盘。")
            }

            VStack(alignment: .leading, spacing: 12) {
                SectionTitle(title: "参考资料", index: "REFERENCES")
                reference("香港天文台 · 天干和地支", url: "https://www.hko.gov.hk/tc/gts/time/stemsandbranches.htm")
                reference("香港天文台 · 二十四节气", url: "https://www.hko.gov.hk/tc/gts/time/24solarterms.htm")
                reference("NASA JPL · DE440 星历", url: "https://ssd.jpl.nasa.gov/doc/de440_de441.html")
                reference("《周易正义·说卦》", url: "https://zh.wikisource.org/wiki/周易正義/09.05")
                reference("《渊海子平》卷一", url: "https://www.chinese-classics.org/read/shushu/mingli/yuan-hai-zi-ping/001")
            }
        }
    }

    private func method<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Ink.goldLight)
                .accessibilityAddTraits(.isHeader)
            content()
                .font(.system(size: 13))
                .foregroundStyle(Ink.secondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(Panel(radius: 11))
    }

    private func reference(_ title: String, url: String) -> some View {
        Group {
            if let destination = URL(string: url) {
                Link(destination: destination) {
                    Label(title, systemImage: "arrow.up.right")
                        .font(.system(size: 12))
                        .foregroundStyle(Ink.goldLight)
                }
            }
        }
    }
}
