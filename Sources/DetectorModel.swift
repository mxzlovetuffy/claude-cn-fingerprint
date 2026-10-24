//
//  DetectorModel.swift
//  扫描流程、计分、报告
//

import SwiftUI
import AppKit

@MainActor
final class DetectorModel: ObservableObject {

    /// 单项命中阈值：归一化之后 >= 0.25 就算命中
    static let hitThreshold = 0.25

    let signals = Signal.all

    @Published private(set) var results: [String: SignalResult] = [:]
    @Published private(set) var revealed: Set<String> = []
    @Published private(set) var score: Double = 0
    @Published private(set) var hasRun = false
    @Published var isScanning = false
    @Published var allowPublicProbe = true
    @Published var toast: String?

    private var toastTask: Task<Void, Never>?
    private var scanTask: Task<Void, Never>?

    // MARK: 派生状态

    var hits: Int {
        signals.filter { (results[$0.id]?.ratio ?? 0) >= Self.hitThreshold }.count
    }

    var band: Band { Band(score: score) }

    var isComplete: Bool { hasRun && !isScanning }

    // MARK: 扫描

    func startScan() {
        guard !isScanning else { return }
        scanTask?.cancel()
        scanTask = Task { await scan() }
    }

    func scan() async {
        guard !isScanning else { return }

        isScanning = true
        hasRun = false

        withAnimation(.easeOut(duration: 0.25)) {
            results = [:]
            revealed = []
            score = 0
        }

        for (index, signal) in signals.enumerated() {
            if Task.isCancelled { break }

            // 第一项慢一点，让用户看清动画从哪开始的
            try? await Task.sleep(for: .milliseconds(index == 0 ? 260 : 110))
            let result = await Probes.run(signal.kind, allowNetwork: allowPublicProbe)

            results[signal.id] = result
            withAnimation(.spring(response: 0.5, dampingFraction: 0.78)) {
                revealed.insert(signal.id)
                score = rawScore()
            }
            try? await Task.sleep(for: .milliseconds(45))
        }

        isScanning = false
        hasRun = true
        showToast(Lang.shared.t("检测完成 · \(band.name) \(Int(score.rounded())) 分",
                                "Done · \(band.name) \(Int(score.rounded())) pts"))
    }

    private func rawScore() -> Double {
        var total = 0.0
        for signal in signals {
            guard let r = results[signal.id] else { continue }
            total += Double(signal.weight) * min(max(r.ratio, 0), 1)
        }
        return min(max(total, 0), 100)
    }

    // MARK: 报告

    func reportText() -> String {
        let zh = Lang.shared.isZh
        let stamp = DateFormatter()
        stamp.dateFormat = "yyyy-MM-dd HH:mm"
        let hits = self.hits

        var lines: [String] = [
            zh ? "Claude 中国用户检测器 · 本地报告" : "Claude CN Detector · Local Report",
            zh ? "时间 \(stamp.string(from: Date()))" : "Time \(stamp.string(from: Date()))",
            zh ? "风险分 \(Int(score.rounded()))/100（\(band.name)）"
               : "Risk \(Int(score.rounded()))/100 (\(band.name))",
            zh ? "命中 \(hits)/\(signals.count) 项 · 单项阈值 \(Self.hitThreshold)"
               : "Met \(hits)/\(signals.count) · per-item threshold \(Self.hitThreshold)",
            String(repeating: "─", count: 34),
            ""
        ]

        for signal in signals {
            let r = results[signal.id] ?? SignalResult(ratio: 0, evidence: zh ? "未检测" : "Not tested")
            let percent = String(format: "%3.0f%%", min(max(r.ratio, 0), 1) * 100)
            let weightLabel = zh ? "权重" : "Weight"
            lines.append("\(signal.nameLocal)  \(weightLabel) \(signal.weight)  \(percent)  \(r.evidence)")
        }

        lines.append("")
        lines.append(zh ? "在本机生成，未上传任何数据。" : "Generated locally; nothing uploaded.")
        return lines.joined(separator: "\n")
    }

    func copyReport() {
        let text = reportText()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        showToast(Lang.shared.t("报告已复制到剪贴板", "Report copied to clipboard"))
    }

    // MARK: Toast

    func showToast(_ message: String) {
        toastTask?.cancel()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            toast = message
        }
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.4))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.3)) { self?.toast = nil }
            }
        }
    }
}
