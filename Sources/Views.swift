//
//  Views.swift
//  主界面：顶栏 / 分数环 / 信号卡 / 说明页
//

import SwiftUI

// MARK: - 主按钮样式

struct AccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(
                Capsule().fill(
                    LinearGradient(colors: [Color(hex: 0xE2895F), Color(hex: 0xC25B39)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(
                Capsule().strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.55), .white.opacity(0.08)],
                                   startPoint: .top, endPoint: .bottom),
                                   lineWidth: 0.9)
            )
            .shadow(color: Color(hex: 0xE2895F).opacity(0.38), radius: 12, y: 5)
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

// MARK: - 根视图

enum Tab: String, CaseIterable, Identifiable {
    case scan, why, fix
    var id: String { rawValue }

    var title: String {
        switch self {
        case .scan: return "检测"
        case .why:  return "原理"
        case .fix:  return "降分"
        }
    }
}

struct RootView: View {
    @StateObject private var model = DetectorModel()
    @State private var tab: Tab

    init() {
        // 调试用：CND_TAB=why 可以直接把窗口开到某一页，方便截图
        let raw = ProcessInfo.processInfo.environment["CND_TAB"] ?? "scan"
        _tab = State(initialValue: Tab(rawValue: raw) ?? .scan)
    }

    var body: some View {
        VStack(spacing: 14) {
            TopBar(model: model, tab: $tab)

            Group {
                switch tab {
                case .scan: ScanView(model: model)
                case .why:  WhyView()
                case .fix:  FixView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .transition(.opacity.combined(with: .offset(y: 6)))
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // 背景放 background 里：它那一堆大光斑不参与布局计算
        .background(LiquidBackground())
        .overlay(alignment: .bottom) {
            if let message = model.toast {
                ToastView(text: message)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .preferredColorScheme(.dark)
        .tint(Ink.accent)
        .animation(.easeInOut(duration: 0.28), value: tab)
        .task { await model.scan() }
    }
}

// MARK: - 顶栏

struct TopBar: View {
    @ObservedObject var model: DetectorModel
    @Binding var tab: Tab

    var body: some View {
        HStack(spacing: 12) {
            LogoMark()

            VStack(alignment: .leading, spacing: 1) {
                Text("Claude 中国用户检测器")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Ink.text)
                Text("十项区域与网络指纹 · 本地计算")
                    .font(.system(size: 10))
                    .foregroundStyle(Ink.ghost)
            }

            Spacer(minLength: 16)

            SegmentedTabs(tab: $tab)

            Spacer(minLength: 16)

            Button {
                model.copyReport()
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 11.5, weight: .medium))
                    .frame(width: 26, height: 22)
            }
            .buttonStyle(.glass)
            .help("复制本地报告")
            .disabled(!model.hasRun)

            Button {
                model.startScan()
            } label: {
                HStack(spacing: 6) {
                    if model.isScanning {
                        ProgressView().controlSize(.mini).scaleEffect(0.7)
                    } else {
                        Image(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
                            .font(.system(size: 11, weight: .medium))
                    }
                    Text(model.isScanning ? "检测中" : (model.hasRun ? "重新检测" : "开始检测"))
                        .font(.system(size: 11.5, weight: .medium))
                }
            }
            .buttonStyle(AccentButtonStyle())
            .disabled(model.isScanning)
        }
        .padding(.leading, 76)
        .padding(.trailing, 14)
        .padding(.vertical, 10)
        .glassSurface(radius: 18, tint: .white.opacity(0.06))
    }
}

struct LogoMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 9)
                .fill(AngularGradient(colors: [Ink.violet, Ink.cyan, Ink.mint, Ink.violet],
                                      center: .center))
            RoundedRectangle(cornerRadius: 9)
                .fill(LinearGradient(colors: [Color(hex: 0x15172B), Color(hex: 0x0A0B14)],
                                     startPoint: .top, endPoint: .bottom))
                .padding(1.2)

            Circle()
                .trim(from: 0.06, to: 0.82)
                .stroke(.white, style: StrokeStyle(lineWidth: 1.7, lineCap: .round))
                .frame(width: 12, height: 12)
                .rotationEffect(.degrees(12))
            Circle().fill(.white).frame(width: 2.4, height: 2.4)
        }
        .frame(width: 30, height: 30)
        .shadow(color: Ink.violet.opacity(0.5), radius: 8, y: 2)
    }
}

struct SegmentedTabs: View {
    @Binding var tab: Tab
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Tab.allCases) { item in
                Button {
                    withAnimation(.snappy(duration: 0.26)) { tab = item }
                } label: {
                    Text(item.title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(tab == item ? Ink.text : Ink.faint)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 5)
                        .background {
                            if tab == item {
                                Capsule()
                                    .fill(.white.opacity(0.15))
                                    .matchedGeometryEffect(id: "pill", in: ns)
                            }
                        }
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Capsule().fill(.black.opacity(0.22)))
        .overlay(Capsule().strokeBorder(.white.opacity(0.08), lineWidth: 0.6))
    }
}

// MARK: - 检测页

struct ScanView: View {
    @ObservedObject var model: DetectorModel

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(spacing: 12) {
                ScorePanel(model: model)
                ContributionCard(model: model)
            }
            .frame(width: 348)

            SignalBoard(model: model)
                .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - 实时 prompt 预览
//
// 就是 Claude 每次请求都会看到的那一行。日期和时间都取本机当前值，
// 撇号和连字符标出来 —— 隐写位就藏在这些字符上。

struct PromptPreview: View {
    @ObservedObject var model: DetectorModel

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let clockFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    private var zoneText: String {
        if let evidence = model.results["timezone"]?.evidence, !evidence.isEmpty {
            return evidence
        }
        let seconds = TimeZone.current.secondsFromGMT()
        return String(format: "%@ · UTC%@%02d:%02d",
                      TimeZone.current.identifier,
                      seconds >= 0 ? "+" : "−",
                      abs(seconds / 3600), abs(seconds % 3600) / 60)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text("PROMPT · 实时")
                        .font(.system(size: 7.5, weight: .semibold, design: .monospaced))
                        .tracking(1.3)
                        .foregroundStyle(Ink.ghost)
                    Spacer(minLength: 8)
                    Text(zoneText)
                        .font(.system(size: 7.5, design: .monospaced))
                        .foregroundStyle(Ink.ghost)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }

                HStack(alignment: .firstTextBaseline, spacing: 0) {
                    (Text("Today") + mark("’") + Text("s date: ")
                     + Text(Self.dayFormatter.string(from: context.date)))
                        .font(.system(size: 11.5, design: .monospaced))
                        .foregroundStyle(Ink.text)

                    Spacer(minLength: 8)

                    Text(Self.clockFormatter.string(from: context.date))
                        .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                        .monospacedDigit()
                        .foregroundStyle(Ink.amber)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.24)))
            .overlay(RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.white.opacity(0.07), lineWidth: 0.6))
        }
    }

    private func mark(_ text: String) -> Text {
        Text(text)
            .foregroundColor(Ink.amber)
            .underline(true, color: Ink.amber.opacity(0.55))
    }
}

// MARK: 分数面板

struct ScorePanel: View {
    @ObservedObject var model: DetectorModel

    var body: some View {
        VStack(spacing: 0) {
            ScoreRing(model: model, size: 248)

            Text(model.hasRun ? model.band.verdict : (model.score > 0 ? "正在逐项确认…" : "十项指纹，加权一分不差"))
                .font(.system(size: 11.5))
                .foregroundStyle(Ink.soft)
                .padding(.top, 12)

            PromptPreview(model: model)
                .padding(.top, 12)

            Text("撇号与连字符是隐写位，每次请求都会带上这一行")
                .font(.system(size: 8.5))
                .foregroundStyle(Ink.ghost)
                .padding(.top, 5)

            Button {
                model.startScan()
            } label: {
                HStack(spacing: 7) {
                    if model.isScanning {
                        ProgressView().controlSize(.small).scaleEffect(0.75)
                    } else {
                        Text(model.hasRun ? "重新检测" : "开始检测")
                            .font(.system(size: 12, weight: .medium))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
            }
            .buttonStyle(AccentButtonStyle())
            .disabled(model.isScanning)
            .padding(.top, 16)

            ScoreScale(score: model.score)
                .padding(.top, 14)

            HStack(spacing: 5) {
                Image(systemName: "lock.fill").font(.system(size: 8))
                Text("数据不出本机")
            }
            .font(.system(size: 9.5))
            .foregroundStyle(Ink.ghost)
            .padding(.top, 12)
        }
        .padding(20)
        .glassSurface(radius: 26, tint: .white.opacity(0.05))
    }
}

struct ScoreRing: View {
    @ObservedObject var model: DetectorModel
    var size: CGFloat

    // 每项按权重占角，中间留 2° 的缝
    private static let arcs: [String: (CGFloat, CGFloat)] = {
        var map: [String: (CGFloat, CGFloat)] = [:]
        var cursor: CGFloat = 0
        for signal in Signal.all {
            let span = CGFloat(signal.weight) / 100 * 360
            map[signal.id] = ((cursor + 2.0) / 360, (cursor + span - 2.0) / 360)
            cursor += span
        }
        return map
    }()

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [model.band.color.opacity(model.hasRun ? 0.22 : 0.06), .clear],
                                     center: .center, startRadius: 0, endRadius: size * 0.52))
                .blur(radius: 12)

            Circle()
                .stroke(Color.white.opacity(0.055), lineWidth: 10)

            ForEach(model.signals) { signal in
                let arc = Self.arcs[signal.id] ?? (0, 0)
                let shown = model.revealed.contains(signal.id)
                let ratio = model.results[signal.id]?.ratio ?? 0

                Circle()
                    .trim(from: arc.0, to: shown ? arc.1 : arc.0)
                    .stroke(color(for: ratio),
                            style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: shown && ratio >= 0.25 ? color(for: ratio).opacity(0.55) : .clear,
                            radius: 5)
                    .animation(.spring(response: 0.55, dampingFraction: 0.8), value: model.revealed)
            }

            center
        }
        .frame(width: size, height: size)
    }

    private var center: some View {
        VStack(spacing: 2) {
            Text("RISK SCORE")
                .font(.system(size: 8.5, weight: .semibold))
                .tracking(2.2)
                .foregroundStyle(Ink.ghost)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(Int(model.score.rounded()))")
                    .font(.system(size: 58, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Ink.text)
                    .contentTransition(.numericText(value: model.score))
                Text("/100")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Ink.ghost)
            }
            .padding(.top, -4)

            Text(model.score > 0 ? model.band.name : "等待检测")
                .font(.system(size: 10.5, weight: .medium))
                .foregroundStyle(model.hasRun ? model.band.color : Ink.faint)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(Capsule().fill((model.hasRun ? model.band.color : Color.white).opacity(0.11)))
                .overlay(Capsule().strokeBorder((model.hasRun ? model.band.color : Color.white).opacity(0.22),
                                                lineWidth: 0.6))

            Text("命中 \(model.hits) / \(model.signals.count)")
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundStyle(Ink.ghost)
                .padding(.top, 4)
        }
        .animation(.easeOut(duration: 0.4), value: model.score)
    }

    private func color(for ratio: Double) -> Color {
        if ratio >= 0.7 { return Ink.hot }
        if ratio >= DetectorModel.hitThreshold { return Ink.warm }
        return Ink.mint.opacity(0.34)
    }
}

struct ScoreScale: View {
    var score: Double

    var body: some View {
        VStack(spacing: 5) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(LinearGradient(colors: [Ink.mint, Ink.warm, Ink.hot],
                                             startPoint: .leading, endPoint: .trailing))
                        .opacity(0.55)
                        .frame(height: 5)

                    Circle()
                        .fill(.white)
                        .frame(width: 8, height: 8)
                        .shadow(color: .white.opacity(0.7), radius: 4)
                        .offset(x: min(max(0, geo.size.width * score / 100 - 4), geo.size.width - 8))
                }
                .frame(height: 8)
            }
            .frame(height: 8)

            HStack {
                Text("低 0–30")
                Spacer()
                Text("中 31–60")
                Spacer()
                Text("高 61–100")
            }
            .font(.system(size: 8.5, design: .monospaced))
            .foregroundStyle(Ink.faint.opacity(0.8))
        }
    }
}

// MARK: 贡献排行

struct Contribution: Identifiable {
    let signal: Signal
    let result: SignalResult
    var id: String { signal.id }
    var points: Double { Double(signal.weight) * result.ratio }
}

struct ContributionCard: View {
    @ObservedObject var model: DetectorModel

    private var top: [Contribution] {
        model.signals
            .compactMap { signal -> Contribution? in
                guard let result = model.results[signal.id] else { return nil }
                return Contribution(signal: signal, result: result)
            }
            .sorted { $0.points > $1.points }
            .prefix(3)
            .map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("主要贡献")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Ink.text)
                Spacer()
                Text("权重 × 命中")
                    .font(.system(size: 8.5, design: .monospaced))
                    .foregroundStyle(Ink.ghost)
            }

            if top.isEmpty {
                Text("还没有数据，先跑一次检测。")
                    .font(.system(size: 10.5))
                    .foregroundStyle(Ink.faint)
                    .padding(.vertical, 6)
            } else {
                ForEach(top) { item in
                    row(item.signal, item.result)
                }
            }

            Divider().overlay(Color.white.opacity(0.07))

            Toggle(isOn: $model.allowPublicProbe) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("公网出口探测")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Ink.soft)
                    Text("会访问一次 ipapi.co")
                        .font(.system(size: 8.5))
                        .foregroundStyle(Ink.ghost)
                }
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            .tint(Ink.violet)
        }
        .padding(14)
        .glassSurface(radius: 20, tint: .white.opacity(0.03))
    }

    private func row(_ signal: Signal, _ result: SignalResult) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(signal.name)
                    .font(.system(size: 10.5))
                    .foregroundStyle(Ink.soft)
                Spacer()
                Text("+" + String(format: "%.1f", Double(signal.weight) * result.ratio))
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(result.ratio >= DetectorModel.hitThreshold ? Ink.warm : Ink.ghost)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.07))
                    Capsule()
                        .fill(LinearGradient(colors: [Ink.amber, Ink.claude],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(2, geo.size.width * min(result.ratio, 1)))
                }
            }
            .frame(height: 3)
        }
    }
}

// MARK: 信号面板

struct SignalBoard: View {
    @ObservedObject var model: DetectorModel

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("检测哪些信号")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Ink.text)
                    Text("十项区域与网络指纹，加权得出 0–100 风险分")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Ink.faint)
                }
                Spacer(minLength: 12)
                if model.isScanning {
                    ScanDots()
                }
                Text("10 项 · 权重 100")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Ink.ghost)
            }

            ScrollView(.vertical, showsIndicators: false) {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(model.signals) { signal in
                        SignalCard(signal: signal,
                                   result: model.results[signal.id],
                                   revealed: model.revealed.contains(signal.id))
                    }
                }
                .padding(.bottom, 2)
            }

            Text("命中阈值 0.25 · 分档 低 0–30 / 中 31–60 / 高 61–100")
                .font(.system(size: 8.5, design: .monospaced))
                .foregroundStyle(Ink.ghost)
        }
    }
}

struct ScanDots: View {
    @State private var on = false

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Ink.cyan)
                    .frame(width: 3.5, height: 3.5)
                    .opacity(on ? 1 : 0.22)
                    .animation(.easeInOut(duration: 0.5)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.16), value: on)
            }
        }
        .onAppear { on = true }
    }
}

struct SignalCard: View {
    let signal: Signal
    let result: SignalResult?
    let revealed: Bool

    @State private var hover = false

    private var ratio: Double { min(max(result?.ratio ?? 0, 0), 1) }
    private var isHit: Bool { ratio >= DetectorModel.hitThreshold }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(signal.name)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Ink.text)

                if let note = signal.note {
                    Pill(text: note, color: note == "强信号" ? Ink.hot : Ink.claude)
                }

                Spacer(minLength: 6)

                Text("\(signal.weight)")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(isHit ? Ink.warm : Ink.soft)
                    .contentTransition(.numericText())
            }

            Text(evidenceText)
                .font(.system(size: 9.5, design: .monospaced))
                .foregroundStyle(revealed ? Ink.soft : Ink.ghost)
                .lineLimit(2, reservesSpace: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 6)

            Spacer(minLength: 4)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.07))
                    Capsule()
                        .fill(LinearGradient(colors: isHit ? [Ink.warm, Ink.hot]
                                                           : [Ink.cyan.opacity(0.75), Ink.violet.opacity(0.9)],
                                             startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(0, geo.size.width * ratio))
                }
            }
            .frame(height: 3)

            HStack(spacing: 6) {
                StatusPill(ratio: ratio, revealed: revealed)
                Spacer()
                Text("+" + String(format: "%.1f", Double(signal.weight) * ratio))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Ink.ghost)
            }
            .padding(.top, 7)
        }
        .padding(12)
        .frame(height: 104)
        .glassSurface(radius: 15, tint: tint)
        .overlay {
            RoundedRectangle(cornerRadius: 15)
                .strokeBorder(isHit ? Ink.hot.opacity(0.22) : .clear, lineWidth: 0.8)
                .allowsHitTesting(false)
        }
        .scaleEffect(hover ? 1.006 : 1)
        .animation(.easeOut(duration: 0.2), value: hover)
        .onHover { hover = $0 }
    }

    private var tint: Color {
        if isHit { return Ink.hot.opacity(0.08) }
        if revealed { return Ink.mint.opacity(0.02) }
        return .white.opacity(0.03)
    }

    private var evidenceText: String {
        guard let result, revealed else { return "等待探测…" }
        return result.evidence
    }
}

struct StatusPill: View {
    let ratio: Double
    let revealed: Bool

    private var label: String {
        guard revealed else { return "待检测" }
        if ratio >= 0.7 { return "强命中" }
        if ratio >= DetectorModel.hitThreshold { return "弱命中" }
        if ratio > 0 { return "边缘" }
        return "未命中"
    }

    private var color: Color {
        guard revealed else { return Ink.ghost }
        if ratio >= 0.7 { return Ink.hot }
        if ratio >= DetectorModel.hitThreshold { return Ink.warm }
        if ratio > 0 { return Ink.faint }
        return Ink.mint.opacity(0.85)
    }

    var body: some View {
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 4.5, height: 4.5)
            Text(label).font(.system(size: 9.5))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 2)
        .background(Capsule().fill(color.opacity(0.11)))
        .overlay(Capsule().strokeBorder(color.opacity(0.22), lineWidth: 0.5))
    }
}

// MARK: - 原理页

struct WhyView: View {
    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                PageHeader(kicker: "MECHANISM",
                           title: "检测原理",
                           subtitle: "它读的，和你浏览器此刻愿意暴露的东西是同一批。")

                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        Prose("""
                        当 Claude Code 通过 ANTHROPIC_BASE_URL 指向中转端点时，据公开逆向分析，它会读取操作系统时区与中转 hostname，再把结果用 Unicode 隐写术藏进 system prompt：「Today’s date」那一行的日期分隔符和 4 种几乎一样的撇号变体，编码了你是否像中国用户。
                        """)

                        Prose("""
                        网页读不到 Claude Code 能读的全部信息，但关键信号完全一致：本工具在系统层面读取同一个时区，再叠加语言、字体、网络出口、国产 App、机型、区域与偏移九项指纹，加权得分。得分 ≥ 0.25 计为命中；分档：低 0–30、中 31–60、高 61–100。
                        """)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    SnippetCard()
                        .frame(width: 400)
                }

                PageHeader(kicker: "WHY",
                           title: "为什么会被判为「中国用户」",
                           subtitle: nil,
                           compact: true)

                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        Prose("""
                        Anthropic 并不在中国大陆销售 Claude，而 Claude Code 被曝会把「看起来像中国」的流量视为更高风险。这个判定并不是一个开关，而是把多个弱信号叠加成一个概率。系统时区是单项里最重的一环 —— 它伴随每一次请求，又很难被无意伪装；但语言、字体、设备品牌与网络都会在它之上继续加权。
                        """)
                        Prose("""
                        整个环境之所以会泄露这么多，是因为区域设置会渗透到方方面面：系统时区决定了 Intl 与 Date，语言偏好决定了请求头里的 Accept-Language，而系统自带的字体可以被逐个枚举。如果再让 Claude Code 走一层中转，中转的 hostname 本身又成了一个信号。
                        """)
                        Prose("""
                        这些信号单看没有一个是决定性的，而这恰恰是风险会累积的原因：一个美国时区，配上一整套中文字体和一个微信 WebView，照样会被读成可疑。
                        """)
                    }

                    WeightTable()
                        .frame(width: 400)
                }
            }
            .frame(maxWidth: 1040, alignment: .leading)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 8)
        }
    }
}

struct PageHeader: View {
    var kicker: String
    var title: String
    var subtitle: String?
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(kicker)
                .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                .tracking(2)
                .foregroundStyle(Ink.ghost)
            Text(title)
                .font(.system(size: compact ? 16 : 21, weight: .semibold))
                .foregroundStyle(Ink.text)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(Ink.faint)
                    .padding(.top, 2)
            }
        }
        .padding(.top, compact ? 6 : 0)
    }
}

struct Prose: View {
    var text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 11.8))
            .lineSpacing(5)
            .foregroundStyle(Color.white.opacity(0.78))
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct SnippetCard: View {
    private func glyph(_ s: String) -> Text {
        Text(s).foregroundColor(Ink.warm).underline(true, color: Ink.warm.opacity(0.5))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 5) {
                Circle().fill(Ink.hot.opacity(0.65)).frame(width: 7, height: 7)
                Circle().fill(Ink.warm.opacity(0.65)).frame(width: 7, height: 7)
                Circle().fill(Ink.mint.opacity(0.6)).frame(width: 7, height: 7)
                Spacer()
                Text("SYSTEM PROMPT · 片段")
                    .font(.system(size: 7.5, weight: .medium, design: .monospaced))
                    .tracking(1.2)
                    .foregroundStyle(Ink.ghost)
            }

            (Text("Today")
             + glyph("’")
             + Text("s date: 2026")
             + glyph("‑")
             + Text("10")
             + glyph("‑")
             + Text("24."))
                .font(.system(size: 13.5, design: .monospaced))
                .foregroundStyle(Ink.text)

            VStack(spacing: 5) {
                glyphRow("’", "U+2019", "撇号变体")
                glyphRow("ʹ", "U+02B9", "修饰撇号")
                glyphRow("ʼ", "U+02BC", "送气符号")
                glyphRow("‑", "U+2011", "不换行连字符")
            }

            Text("四个几乎一样的撇号 × 两种连字符，肉眼分辨不出差别，却足以编出几个 bit。")
                .font(.system(size: 9.5))
                .foregroundStyle(Ink.faint)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .glassSurface(radius: 18, tint: .black.opacity(0.12))
    }

    private func glyphRow(_ symbol: String, _ code: String, _ label: String) -> some View {
        HStack(spacing: 8) {
            Text(symbol)
                .font(.system(size: 15, design: .monospaced))
                .foregroundStyle(Ink.warm)
                .frame(width: 14)
            Text(code)
                .font(.system(size: 8.5, design: .monospaced))
                .foregroundStyle(Ink.ghost)
                .frame(width: 48, alignment: .leading)
            Text(label)
                .font(.system(size: 9.5))
                .foregroundStyle(Ink.faint)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 7).fill(.white.opacity(0.035)))
    }
}

struct WeightTable: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("权重表")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Ink.text)

            ForEach(Signal.all) { signal in
                HStack(spacing: 8) {
                    Text(signal.name)
                        .font(.system(size: 9.5))
                        .foregroundStyle(Ink.soft)
                        .lineLimit(1)
                        .frame(width: 112, alignment: .leading)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.06))
                            Capsule()
                                .fill(LinearGradient(colors: [Ink.claude.opacity(0.75), Ink.amber.opacity(0.75)],
                                                     startPoint: .leading, endPoint: .trailing))
                                .frame(width: geo.size.width * CGFloat(signal.weight) / 24)
                        }
                    }
                    .frame(height: 3)

                    Text("\(signal.weight)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Ink.faint)
                        .frame(width: 18, alignment: .trailing)
                }
            }
        }
        .padding(14)
        .glassSurface(radius: 18, tint: .black.opacity(0.12))
    }
}

// MARK: - 降分页

struct FixView: View {
    private struct Step: Identifiable {
        let id = UUID()
        let title: String
        let body: String
        let weight: String
    }

    private let steps: [Step] = [
        Step(title: "把系统时区改成非中国时区",
             body: "例如 America/New_York 或 Europe/London，并确认偏移不再是 UTC+8。逆向分析披露 Claude Code 直接读取的信号只有这一项，所以它在本页评分中权重最高。",
             weight: "时区 · 24"),
        Step(title: "把 zh-Hans / zh-CN 从语言列表首位移除",
             body: "让首选语言以英文或其他非中文 locale 打头。注意是「首位」—— 中文留在列表末尾仍然是弱信号，但不再是强信号。",
             weight: "语言 · 18"),
        Step(title: "隔离中文与厂商字体",
             body: "苹方、微软雅黑、MiSans、鸿蒙黑体 —— 换一台干净的机器或用一个独立的用户账户，让字体枚举找不到任何明显的中文痕迹。",
             weight: "字体 · 24"),
        Step(title: "处理网络出口",
             body: "走原生住宅 IP 而非数据中心 IP，避免真实网络与地理位置盖过一个本来已经很干净的环境。",
             weight: "网络 · 10"),
        Step(title: "保持 ANTHROPIC_BASE_URL 的 hostname 中性",
             body: "避开含敏感关键词或 AI 实验室名称的域名；若宿主机在中国，还需覆盖 TZ 环境变量。",
             weight: "中转 · —")
    ]

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 14) {
                PageHeader(kicker: "MITIGATION",
                           title: "如何降低你的风险分",
                           subtitle: "从上往下做 —— 时区和语言的权重最高。")

                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    HStack(alignment: .top, spacing: 14) {
                        Text(String(format: "%02d", index + 1))
                            .font(.system(size: 15, weight: .medium, design: .monospaced))
                            .foregroundStyle(Ink.claude.opacity(0.9))
                            .frame(width: 30, alignment: .leading)
                            .padding(.top, 1)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(step.title)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Ink.text)
                            Text(step.body)
                                .font(.system(size: 10.8))
                                .lineSpacing(3.5)
                                .foregroundStyle(Color.white.opacity(0.76))
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 12)

                        Text(step.weight)
                            .font(.system(size: 8.5, design: .monospaced))
                            .foregroundStyle(Ink.faint)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(.white.opacity(0.05)))
                            .overlay(Capsule().strokeBorder(.white.opacity(0.08), lineWidth: 0.5))
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassSurface(radius: 16, tint: .black.opacity(0.16))
                }

                Text("本页仅用于隐私自检与指纹教育，结论不保证与 Anthropic 的实际风控模型一致。所有检测都在本机完成，唯一的对外请求是可选开启的公网 IP 查询。")
                    .font(.system(size: 9.5))
                    .foregroundStyle(Ink.ghost)
                    .lineSpacing(3)
                    .padding(.top, 4)
            }
            .frame(maxWidth: 1040, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Toast

struct ToastView: View {
    let text: String

    var body: some View {
        VStack {
            Spacer()
            Text(text)
                .foregroundStyle(Ink.text)
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .glassSurface(radius: 12, tint: .white.opacity(0.06))
                .padding(.bottom, 26)
        }
        .allowsHitTesting(false)
    }
}
