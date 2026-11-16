import SwiftUI
import YiLiCore

enum Ink {
    static let background = color(0x131613)
    static let sidebar = color(0x181b17)
    static let panel = color(0x1a1d19)
    static let line = color(0x34372e)
    static let goldLine = color(0x574932)
    static let gold = color(0xc6a367)
    static let goldLight = color(0xe0c38d)
    static let text = color(0xece6d6)
    static let secondary = color(0xbab6a7)
    static let quiet = color(0xa29e8e)

    static func color(_ hex: UInt32) -> Color {
        Color(
            red: Double((hex >> 16) & 0xff) / 255,
            green: Double((hex >> 8) & 0xff) / 255,
            blue: Double(hex & 0xff) / 255
        )
    }

    static func element(_ element: Element) -> Color {
        switch element {
        case .wood: color(0x9db58e)
        case .fire: color(0xe39a83)
        case .earth: color(0xc6a367)
        case .metal: color(0xd1cdb8)
        case .water: color(0x92b5c3)
        }
    }
}

func song(_ size: CGFloat) -> Font {
    .custom("STSongti-SC-Regular", size: size)
}

struct IndexLabel: View {
    let title: String

    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .tracking(2)
            .foregroundStyle(Ink.gold)
    }
}

struct SectionTitle: View {
    let title: String
    let index: String

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(song(24))
                .foregroundStyle(Ink.text)
            IndexLabel(index)
                .accessibilityHidden(true)
            Rectangle()
                .fill(Ink.line)
                .frame(height: 1)
                .padding(.leading, 4)
        }
        .accessibilityAddTraits(.isHeader)
    }
}

struct PageTitle: View {
    let title: String
    let index: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle().fill(Ink.gold).frame(width: 5, height: 5)
                IndexLabel(index)
            }
            .accessibilityHidden(true)
            Text(title)
                .font(song(44))
                .tracking(2)
                .foregroundStyle(Ink.text)
                .accessibilityAddTraits(.isHeader)
        }
    }
}

struct Panel: ViewModifier {
    var radius: CGFloat = 14

    func body(content: Content) -> some View {
        content
            .background(Ink.panel, in: RoundedRectangle(cornerRadius: radius))
            .overlay {
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(Ink.line, lineWidth: 1)
                    .allowsHitTesting(false)
            }
    }
}

struct GoldButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Ink.background)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(
                configuration.isPressed ? Ink.gold : Ink.goldLight,
                in: RoundedRectangle(cornerRadius: 7)
            )
    }
}

struct OutlineButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Ink.goldLight)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                configuration.isPressed ? Ink.gold.opacity(0.15) : Ink.panel,
                in: RoundedRectangle(cornerRadius: 7)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .strokeBorder(Ink.goldLine, lineWidth: 1)
                    .allowsHitTesting(false)
            }
    }
}

struct Sidebar: View {
    @Binding var page: AlmanacPage
    let profile: BirthProfile?
    let edit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 11) {
                AlmanacMark()
                    .frame(width: 38, height: 38)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("易历")
                        .font(song(27))
                        .tracking(3)
                        .foregroundStyle(Ink.text)
                    IndexLabel("YI LI")
                }
            }
            .padding(.bottom, 27)

            Rectangle().fill(Ink.line).frame(height: 1)

            Text("历  象")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Ink.quiet)
                .padding(.leading, 10)
                .padding(.top, 24)
                .padding(.bottom, 9)

            VStack(spacing: 5) {
                navigationButton(.daily)
                navigationButton(.natal)
                navigationButton(.methods)
            }

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: "lock")
                    .font(.system(size: 10))
                Text("出生资料仅保存在本机")
                    .font(.system(size: 10))
            }
            .foregroundStyle(Ink.quiet)
            .padding(.leading, 5)
            .padding(.bottom, 12)

            Button(action: edit) {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.crop.circle")
                            .foregroundStyle(Ink.gold)
                        Text(profile?.isSample == false ? "我的出生资料" : "体验命盘")
                            .foregroundStyle(Ink.text)
                        Spacer(minLength: 2)
                        Image(systemName: "pencil")
                            .font(.system(size: 10))
                            .foregroundStyle(Ink.gold)
                    }
                    .font(.system(size: 12, weight: .medium))

                    if let birth = profile?.birth {
                        Text(CivilDate.birthStamp(birth))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Ink.secondary)
                    } else {
                        Text("输入出生资料")
                            .font(.system(size: 11))
                            .foregroundStyle(Ink.secondary)
                    }
                }
                .padding(11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .modifier(Panel(radius: 9))
            }
            .buttonStyle(.plain)
            .keyboardShortcut("e", modifiers: .command)
            .help("输入或修改出生资料")
            .accessibilityLabel("编辑出生资料")
        }
        .padding(.horizontal, 18)
        .padding(.top, 54)
        .padding(.bottom, 20)
        .frame(maxHeight: .infinity)
        .background(Ink.sidebar)
    }

    private func navigationButton(_ target: AlmanacPage) -> some View {
        let selected = page == target
        return Button {
            page = target
        } label: {
            HStack(spacing: 10) {
                Image(systemName: target.icon)
                    .font(.system(size: 14, weight: .regular))
                    .frame(width: 19)
                Text(target.title)
                    .font(.system(size: 13, weight: selected ? .semibold : .regular))
                Spacer()
                if selected {
                    Circle().fill(Ink.gold).frame(width: 4, height: 4)
                }
            }
            .foregroundStyle(selected ? Ink.goldLight : Ink.secondary)
            .padding(.horizontal, 10)
            .frame(height: 39)
            .background(
                selected ? Ink.gold.opacity(0.10) : .clear,
                in: RoundedRectangle(cornerRadius: 7)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct AlmanacMark: View {
    var body: some View {
        ZStack {
            Circle().strokeBorder(Ink.goldLine, lineWidth: 1)
            Circle().strokeBorder(Ink.gold.opacity(0.35), lineWidth: 1).padding(4)
            VStack(spacing: 3) {
                Rectangle().frame(width: 16, height: 1.5)
                HStack(spacing: 4) {
                    Rectangle().frame(width: 6, height: 1.5)
                    Rectangle().frame(width: 6, height: 1.5)
                }
                Rectangle().frame(width: 16, height: 1.5)
            }
            .foregroundStyle(Ink.goldLight)
        }
    }
}
