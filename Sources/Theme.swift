//
//  Theme.swift
//  Claude 中国用户检测器 — 视觉层
//
//  玻璃质感交给系统（macOS 26 的 Liquid Glass），这里只负责
//  背景、排版和那点霓虹色。别在这个文件里放逻辑。
//

import SwiftUI

// MARK: - 颜色

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

enum Ink {
    static let text = Color(hex: 0xF3F5FA)
    static let soft = Color.white.opacity(0.72)
    static let faint = Color.white.opacity(0.42)
    static let ghost = Color.white.opacity(0.24)

    static let mint = Color(hex: 0x6FE0C0)
    static let warm = Color(hex: 0xFFCE73)
    static let hot = Color(hex: 0xFF6A55)
    static let violet = Color(hex: 0xD97757)
    static let accent = Color(hex: 0xE08963)
    static let claude = Color(hex: 0xD97757)
    static let amber = Color(hex: 0xE9A97A)
    static let cream = Color(hex: 0xF4E4CB)
    static let cyan = Color(hex: 0x5AD2FF)

    static let bgTop = Color(hex: 0x0B0D18)
    static let bgBase = Color(hex: 0x05060B)
}

// MARK: - 风险分档

enum Band {
    case low, mid, high

    init(score: Double) {
        self = score <= 30 ? .low : (score <= 60 ? .mid : .high)
    }

    var color: Color {
        switch self {
        case .low: return Ink.mint
        case .mid: return Ink.warm
        case .high: return Ink.hot
        }
    }

    var name: String {
        switch self {
        case .low: return "低风险"
        case .mid: return "中等风险"
        case .high: return "高风险"
        }
    }

    var verdict: String {
        switch self {
        case .low: return "环境看起来足够中性"
        case .mid: return "有若干弱信号，还能继续收紧"
        case .high: return "很像中国大陆的日常环境"
        }
    }
}

// MARK: - 动态背景
//
// 窗口本身是透的（NSVisualEffectView 把桌面糊在身后），
// 上面再压一层缓慢漂移的彩色光斑，玻璃卡片才有东西可以折射。

struct LiquidBackground: View {
    var body: some View {
        ZStack {
            WindowBackdrop()

            // 压暗一点，免得壁纸太亮抢戏
            Color(hex: 0x0A0906).opacity(0.30)

            TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                ZStack {
                    blob(0xE8B04B, 720, sin(t / 17) * 95 - 300, cos(t / 23) * 85 - 280, 0.19)
                    blob(0xD97757, 620, cos(t / 21) * 110 + 360, sin(t / 19) * 70 - 220, 0.12)
                    blob(0x6E3A1E, 780, sin(t / 25) * 100 + 80, cos(t / 15) * 80 + 380, 0.07)
                    blob(0xF6E3C2, 520, cos(t / 13) * 90 - 460, sin(t / 27) * 75 + 300, 0.10)
                }
                .drawingGroup()
            }

            // 底部压深，让卡片在明亮壁纸上也有对比
            LinearGradient(colors: [.clear, Color(hex: 0x0A0704).opacity(0.24)],
                           startPoint: .center, endPoint: .bottom)
        }
        .ignoresSafeArea()
    }

    private func blob(_ hex: UInt32, _ radius: CGFloat,
                      _ x: CGFloat, _ y: CGFloat, _ alpha: Double) -> some View {
        let c = Color(hex: hex)
        return Circle()
            .fill(RadialGradient(colors: [c.opacity(alpha), c.opacity(0)],
                                center: .center, startRadius: 0, endRadius: radius))
            .frame(width: radius * 2, height: radius * 2)
            .blur(radius: 26)
            .offset(x: x, y: y)
    }
}

// MARK: - 玻璃修饰

/// 真正的毛玻璃桌面背景。放在窗口最底层，卡片才有「透」的感觉。
struct WindowBackdrop: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .underWindowBackground
        view.blendingMode = .behindWindow
        view.state = .active
        view.appearance = NSAppearance(named: .darkAqua)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct GlassSurface: ViewModifier {
    var radius: CGFloat = 20
    var tint: Color = .white.opacity(0.04)

    func body(content: Content) -> some View {
        content
            .glassEffect(.regular.tint(tint), in: .rect(cornerRadius: radius))
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: radius)
                    .fill(LinearGradient(colors: [.white.opacity(0.05), .clear],
                                         startPoint: .top, endPoint: .bottom))
                    .frame(height: 34)
                    .allowsHitTesting(false)
                    .mask(RoundedRectangle(cornerRadius: radius))
            }
            .overlay {
                // 一条很淡的高光边，暗色背景上全靠它把卡片“立”起来
                RoundedRectangle(cornerRadius: radius)
                    .strokeBorder(
                        LinearGradient(colors: [.white.opacity(0.20), .white.opacity(0.02)],
                                      startPoint: .topLeading,
                                      endPoint: .bottomTrailing),
                        lineWidth: 0.75)
                    .allowsHitTesting(false)
            }
    }
}

extension View {
    func glassSurface(radius: CGFloat = 20, tint: Color = .white.opacity(0.04)) -> some View {
        modifier(GlassSurface(radius: radius, tint: tint))
    }
}

// MARK: - 小部件

/// 等宽小标签，用来放日期、数值这些怕抖的东西
struct MonoLabel: View {
    var text: String
    var size: CGFloat = 10.5
    var color: Color = Ink.faint

    var body: some View {
        Text(text)
            .font(.system(size: size, design: .monospaced))
            .foregroundStyle(color)
    }
}

struct Pill: View {
    var text: String
    var color: Color
    var filled: Bool = false

    var body: some View {
        Text(text)
            .font(.system(size: 9.5, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 7)
            .padding(.vertical, 2.5)
            .background(Capsule().fill(color.opacity(filled ? 0.22 : 0.10)))
            .overlay(Capsule().strokeBorder(color.opacity(0.30), lineWidth: 0.6))
    }
}
