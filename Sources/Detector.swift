//
//  Detector.swift
//  十项指纹探测 + 加权计分
//
//  权重是照着一份公开的逆向分析拆解定的：系统时区 24，语言 18，
//  字体 14 + 10，网络 10，浏览器 8，设备 6，Intl 4，偏移 3，emoji 3。
//  合计 100，所以分数不用再归一化。
//

import Foundation
import AppKit
import CoreText
import SystemConfiguration

// MARK: - 数据结构

struct SignalResult {
    var ratio: Double          // 0...1，命中程度
    var evidence: String       // 具体看到了什么，直接显示在卡片上
    var note: String = ""      // 可选的一句补充
}

enum ProbeKind {
    case timezone
    case language
    case cjkFonts
    case vendorFonts
    case network
    case browserApps
    case device
    case localeSetting
    case utcOffset
    case emoji
}

struct Signal: Identifiable {
    let id: String
    let name: String
    let weight: Int
    let note: String?
    let desc: String
    let kind: ProbeKind

    static let all: [Signal] = [
        Signal(id: "timezone", name: "系统时区", weight: 24, note: "Claude 同款",
               desc: "Claude Code 直接读的就是这一个值，和 Asia/Shanghai、Asia/Urumqi 等中国时区比对。",
               kind: .timezone),

        Signal(id: "language", name: "系统语言", weight: 18, note: nil,
               desc: "取 AppleLanguages 的首位；zh-Hans / zh-CN 得分最高，中文排在后面也算弱信号。",
               kind: .language),

        Signal(id: "cjkFonts", name: "中文字体", weight: 14, note: nil,
               desc: "在本机字体库里找苹方、宋体、黑体等简繁中文字体 —— 装没装一眼就能看出来。",
               kind: .cjkFonts),

        Signal(id: "vendorFonts", name: "国产厂商字体", weight: 10, note: "强信号",
               desc: "MiSans、鸿蒙黑体、OPPO Sans、方正字库这些基本只会随国产设备或软件一起出现。",
               kind: .vendorFonts),

        Signal(id: "network", name: "网络出口 / IP 暴露", weight: 10, note: "WebRTC 同款",
               desc: "枚举本机网卡地址，并（可选）查询公网出口 IP 与国家归属。浏览器端对应的是 WebRTC 泄露。",
               kind: .network),

        Signal(id: "browserApps", name: "国产浏览器 / WebView", weight: 8, note: nil,
               desc: "扫描已安装的微信、QQ、钉钉、夸克、UC、百度等应用 —— 它们都是内嵌 WebKit 的常客。",
               kind: .browserApps),

        Signal(id: "device", name: "国产品牌设备", weight: 6, note: nil,
               desc: "读取 hw.model 机型标识，匹配鸿蒙、华为、小米、OPPO、vivo 等厂商。",
               kind: .device),

        Signal(id: "localeSetting", name: "Intl 区域设置", weight: 4, note: nil,
               desc: "系统用于日期 / 数字格式化的区域，和时区是两条独立的证据。",
               kind: .localeSetting),

        Signal(id: "utcOffset", name: "时区偏移量", weight: 3, note: nil,
               desc: "秒级偏移是否为 UTC+8，以及是否全年都不带夏令时。",
               kind: .utcOffset),

        Signal(id: "emoji", name: "表情符号渲染风格", weight: 3, note: "弱相关",
               desc: "由系统与字形渲染栈推断 —— macOS 上恒定是 Apple Color Emoji，参考价值有限。",
               kind: .emoji)
    ]
}

// MARK: - 探测实现

enum Probes {

    static func run(_ kind: ProbeKind, allowNetwork: Bool) async -> SignalResult {
        switch kind {
        case .timezone:      return timezone()
        case .language:      return language()
        case .cjkFonts:      return fontProbe(Self.cjkFamilies, strongAt: 3,
                                             label: ("中文字体", "CJK fonts"))
        case .vendorFonts:   return fontProbe(Self.vendorFamilies, strongAt: 2,
                                             label: ("厂商字体", "vendor fonts"))
        case .network:       return await network(allowNetwork: allowNetwork)
        case .browserApps:   return browserApps()
        case .device:        return device()
        case .localeSetting: return localeSetting()
        case .utcOffset:     return utcOffset()
        case .emoji:         return emoji()
        }
    }

    // MARK: 1 · 时区

    static func timezone() -> SignalResult {
        let tz = TimeZone.current
        let id = tz.identifier

        let mainland: Set<String> = [
            "Asia/Shanghai", "Asia/Urumqi", "Asia/Chongqing",
            "Asia/Harbin", "Asia/Kashgar", "Asia/Beijing", "PRC"
        ]
        let greaterChina: Set<String> = ["Asia/Hong_Kong", "Asia/Taipei", "Asia/Macau"]

        var ratio = 0.0
        if mainland.contains(id) { ratio = 1.0 }
        else if greaterChina.contains(id) { ratio = 0.5 }
        else if id == "Etc/GMT-8" || id == "GMT+0800" { ratio = 0.6 }

        let seconds = tz.secondsFromGMT()
        let utc = String(format: "UTC%@%02d:%02d",
                         seconds >= 0 ? "+" : "−",
                         abs(seconds / 3600),
                         abs(seconds % 3600) / 60)

        return SignalResult(
            ratio: ratio,
            evidence: "\(id) · \(utc)",
            note: ratio >= 1 ? Lang.shared.t("和 Claude Code 读到的是同一个值", "Same value Claude Code reads") : ""
        )
    }

    // MARK: 2 · 语言

    static func language() -> SignalResult {
        let languages = Locale.preferredLanguages
        let head = (languages.first ?? "").lowercased()

        var ratio = 0.0
        if head.hasPrefix("zh") {
            let simplified = head == "zh" || head.hasPrefix("zh-hans") || head.hasPrefix("zh-cn") || head.hasPrefix("zh-sg")
            ratio = simplified ? 1.0 : 0.55          // 繁体不是没有，只是没那么典型
        } else if languages.contains(where: { $0.lowercased().hasPrefix("zh") }) {
            ratio = 0.45
        }

        let shown = languages.prefix(4).joined(separator: ", ")
        return SignalResult(
            ratio: ratio,
            evidence: shown.isEmpty ? Lang.shared.t("读取失败", "read failed") : shown,
            note: ratio >= 1 ? Lang.shared.t("首选语言即简体中文", "Primary is Simplified Chinese")
                  : (ratio > 0 ? Lang.shared.t("列表中含中文", "Chinese present in list") : "")
        )
    }

    // MARK: 3 / 4 · 字体

    /// 本机安装的所有字族（小写化，方便对名字）
    private static let installedFamilies: Set<String> = {
        let names = CTFontManagerCopyAvailableFontFamilyNames() as? [String] ?? []
        return Set(names.map { $0.lowercased() })
    }()

    private static let cjkFamilies = [
        "PingFang SC", "PingFang HK", "PingFang TC",
        "Hiragino Sans GB", "STHeiti", "Heiti SC", "Heiti TC",
        "Songti SC", "STSong", "Songti TC",
        "Kaiti SC", "STKaiti", "STFangsong", "FangSong",
        "Yuanti SC", "Lantinghei SC", "Weibei SC", "Xingkai SC", "Baoli SC",
        "Microsoft YaHei", "微软雅黑", "SimSun", "宋体", "SimHei", "黑体",
        "Microsoft JhengHei", "微軟正黑體",
        "Source Han Sans SC", "Noto Sans CJK SC", "Noto Sans SC",
        "Noto Serif CJK SC", "WenQuanYi Micro Hei", "Arial Unicode MS"
    ]

    private static let vendorFamilies = [
        "MiSans", "MiSans VF", "HarmonyOS Sans SC", "HarmonyOS Sans", "HONOR Sans",
        "OPPO Sans", "OPPOSans", "vivo Sans",
        "Alibaba PuHuiTi", "AlibabaPuHuiTi-2", "Ali PuHuiTi",
        "Douyin Sans", "抖音美好体", "DingTalk JinBuTi", "钉钉进步体",
        "FZLanTingHei", "FZLanTingHeiS", "方正兰亭黑",
        "FZShuSong-Z01", "方正书宋", "HYQiHei", "汉仪旗黑"
    ]

    static func fontProbe(_ families: [String], strongAt: Int,
                          label: (zh: String, en: String)) -> SignalResult {
        let hit = families.filter { installedFamilies.contains($0.lowercased()) }

        let ratio: Double
        if hit.isEmpty { ratio = 0 }
        else if hit.count == 1 { ratio = 0.55 }
        else if hit.count < strongAt { ratio = 0.75 }
        else { ratio = 1 }

        let shown = hit.prefix(3).joined(separator: " · ")
        let suffix = hit.count > 3 ? " +\(hit.count - 3)" : ""
        let labelText = Lang.shared.isZh ? label.zh : label.en

        return SignalResult(
            ratio: ratio,
            evidence: hit.isEmpty ? Lang.shared.t("未发现\(labelText)", "No \(labelText) found") : shown + suffix,
            note: hit.isEmpty ? "" : Lang.shared.t("\(hit.count) 个字族可渲染", "\(hit.count) families available")
        )
    }

    // MARK: 5 · 网络

    static func network(allowNetwork: Bool) async -> SignalResult {
        let local = localAddresses()
        let v4 = local.filter { !$0.contains(":") }
        let localText = v4.first ?? local.first ?? "—"

        guard allowNetwork else {
            return SignalResult(ratio: 0.2,
                                evidence: Lang.shared.t("本机 \(localText) · 未查询公网出口",
                                                        "Local \(localText) · egress skipped"),
                                note: Lang.shared.t("公网探测已关闭", "Egress probe off"))
        }

        guard let egress = await fetchEgress() else {
            return SignalResult(ratio: 0.25,
                                evidence: Lang.shared.t("本机 \(localText) · 公网探测超时",
                                                        "Local \(localText) · egress timed out"),
                                note: Lang.shared.t("只有本地地址可见", "Only local addresses visible"))
        }

        let isChina = egress.countryCode.uppercased() == "CN"
        let geo = [egress.city, egress.country].filter { !$0.isEmpty }.joined(separator: ", ")
        var evidence = egress.ip
        if !geo.isEmpty { evidence += " · " + geo }
        if !egress.isp.isEmpty { evidence += " · " + egress.isp }

        return SignalResult(
            ratio: isChina ? 1.0 : 0.4,
            evidence: evidence,
            note: isChina ? Lang.shared.t("出口 IP 落在中国大陆", "Egress IP in mainland China")
                          : Lang.shared.t("公网地址可读，但归属不在中国", "Egress readable, not in China")
        )
    }

    struct Egress {
        var ip: String
        var country: String
        var countryCode: String
        var city: String
        var isp: String
    }

    static func fetchEgress() async -> Egress? {
        if let e = await requestEgress("https://ipapi.co/json/") { return e }
        return await requestEgress("https://ipinfo.io/json")
    }

    private static func requestEgress(_ urlString: String) async -> Egress? {
        guard let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 4.5
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let ip = obj["ip"] as? String, !ip.isEmpty else { return nil }

            // ipapi.co 和 ipinfo.io 字段名不一样，凑合着都能读
            let code = (obj["country_code"] as? String) ?? (obj["country"] as? String) ?? ""
            let countryName = (obj["country_name"] as? String)
                ?? (obj["country"] as? String)
                ?? code
            let city = (obj["city"] as? String) ?? ""
            let isp = (obj["org"] as? String) ?? (obj["isp"] as? String) ?? ""

            return Egress(ip: ip, country: countryName, countryCode: code, city: city, isp: isp)
        } catch {
            return nil
        }
    }

    static func localAddresses() -> [String] {
        var result: [String] = []
        var head: UnsafeMutablePointer<ifaddrs>?

        guard getifaddrs(&head) == 0, let first = head else { return [] }
        defer { freeifaddrs(head) }

        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let flags = Int32(pointer.pointee.ifa_flags)
            guard (flags & IFF_UP) != 0, (flags & IFF_LOOPBACK) == 0 else { continue }
            guard let addr = pointer.pointee.ifa_addr else { continue }

            let family = addr.pointee.sa_family
            guard family == UInt8(AF_INET) || family == UInt8(AF_INET6) else { continue }

            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let size = socklen_t(addr.pointee.sa_len)
            if getnameinfo(addr, size, &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                let ip = String(cString: host)
                if !ip.hasPrefix("fe80") && !ip.hasPrefix("::1") { result.append(ip) }
            }
        }
        return result
    }

    // MARK: 6 · 国产 App / WebView

    static func browserApps() -> SignalResult {
        // 强信号：这些 App 里几乎都有内嵌 WebView，也是最常见的流量来源
        let strong: [(String, String)] = [
            ("com.tencent.xinWeChat", "微信"),
            ("com.tencent.qq", "QQ"),
            ("com.alibaba.DingTalkMac", "钉钉"),
            ("com.tencent.WeWorkMac", "企业微信"),
            ("com.quark.browser", "夸克"),
            ("com.uc.browser.mac", "UC 浏览器")
        ]
        let weak: [(String, String)] = [
            ("com.bytedance.macos.douyin", "抖音"),
            ("com.xingin.xhs", "小红书"),
            ("com.baidu.BaiduNetdisk", "百度网盘"),
            ("com.bilibili.bilibiliPC", "哔哩哔哩"),
            ("com.netease.163music", "网易云音乐")
        ]

        let workspace = NSWorkspace.shared
        var strongHit: [String] = []
        var weakHit: [String] = []

        for (bundle, name) in strong where workspace.urlForApplication(withBundleIdentifier: bundle) != nil {
            strongHit.append(name)
        }
        for (bundle, name) in weak where workspace.urlForApplication(withBundleIdentifier: bundle) != nil {
            weakHit.append(name)
        }

        // 兜底：有些版本没注册 bundle id，直接看 /Applications 里的名字
        let folders = ["/Applications", NSHomeDirectory() + "/Applications"]
        let keywords = ["微信", "QQ", "钉钉", "夸克", "UC浏览器", "百度", "小红书", "抖音"]
        for folder in folders {
            guard let items = try? FileManager.default.contentsOfDirectory(atPath: folder) else { continue }
            for item in items where item.hasSuffix(".app") {
                if keywords.contains(where: { item.contains($0) }) {
                    let label = String(item.dropLast(4))
                    if !strongHit.contains(label) && !weakHit.contains(label) { weakHit.append(label) }
                }
            }
        }

        let all = strongHit + weakHit
        let ratio: Double = strongHit.isEmpty ? (weakHit.isEmpty ? 0 : 0.7) : 1.0

        return SignalResult(
            ratio: ratio,
            evidence: all.isEmpty ? Lang.shared.t("未发现常见国产 App", "No common CN apps found")
                                  : all.prefix(4).joined(separator: " · "),
            note: all.isEmpty ? "" : Lang.shared.t("\(all.count) 个内嵌 WebKit 的宿主",
                                                   "\(all.count) WebKit hosts")
        )
    }

    // MARK: 7 · 设备

    static func device() -> SignalResult {
        let model = sysctlString("hw.model") ?? "unknown"
        let machine = sysctlString("hw.machine") ?? ""

        let vendors = ["HUAWEI", "HONOR", "Xiaomi", "Redmi", "OPPO", "vivo", "Meizu", "HarmonyOS"]
        let haystack = (model + " " + machine).uppercased()
        let hit = vendors.first { haystack.contains($0.uppercased()) }

        return SignalResult(
            ratio: hit == nil ? 0 : 0.9,
            evidence: "\(model) · \(machine)",
            note: hit == nil ? Lang.shared.t("Apple 硬件，和国产厂商无关", "Apple hardware, no CN vendor")
                             : Lang.shared.t("命中 \(hit!)", "Matched \(hit!)")
        )
    }

    private static func sysctlString(_ key: String) -> String? {
        var size = 0
        guard sysctlbyname(key, nil, &size, nil, 0) == 0, size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        guard sysctlbyname(key, &buffer, &size, nil, 0) == 0 else { return nil }
        return String(cString: buffer)
    }

    // MARK: 8 · 区域

    static func localeSetting() -> SignalResult {
        let locale = Locale.current
        let id = locale.identifier                     // zh_CN
        let region = locale.region?.identifier ?? ""   // CN
        let calendar = Calendar.current.identifier

        var ratio = 0.0
        switch region {
        case "CN": ratio = 1.0
        case "HK", "TW", "MO": ratio = 0.55
        default: break
        }
        if ratio == 0 && locale.language.languageCode?.identifier == "zh" { ratio = 0.7 }

        return SignalResult(
            ratio: ratio,
            evidence: "\(id) · region=\(region.isEmpty ? "—" : region) · calendar=\(calendar)",
            note: ratio >= 1 ? Lang.shared.t("区域锁定为中国大陆", "Region locked to mainland China") : ""
        )
    }

    // MARK: 9 · 偏移

    static func utcOffset() -> SignalResult {
        let tz = TimeZone.current
        let now = tz.secondsFromGMT()
        let calendar = Calendar(identifier: .gregorian)

        let january = calendar.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 12)) ?? Date()
        let july = calendar.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 12)) ?? Date()
        let jan = tz.secondsFromGMT(for: january)
        let jul = tz.secondsFromGMT(for: july)

        let fixed = (now == 8 * 3600 && jan == 8 * 3600 && jul == 8 * 3600)
        let ratio: Double = fixed ? 1.0 : (now == 8 * 3600 ? 0.7 : 0)

        func text(_ s: Int) -> String {
            String(format: "%@%02d:%02d", s >= 0 ? "+" : "−", abs(s / 3600), abs(s % 3600) / 60)
        }

        return SignalResult(
            ratio: ratio,
            evidence: Lang.shared.t("现在 \(text(now)) · 1 月 \(text(jan)) · 7 月 \(text(jul))",
                                    "Now \(text(now)) · Jan \(text(jan)) · Jul \(text(jul))"),
            note: fixed ? Lang.shared.t("全年固定 UTC+8，没有夏令时", "Fixed UTC+8 year-round, no DST") : ""
        )
    }

    // MARK: 10 · emoji

    static func emoji() -> SignalResult {
        let hasAppleEmoji = NSFont(name: "Apple Color Emoji", size: 12) != nil
        let region = Locale.current.region?.identifier ?? ""
        let ratio = hasAppleEmoji ? (region == "CN" ? 0.12 : 0.08) : 0.3

        return SignalResult(
            ratio: ratio,
            evidence: hasAppleEmoji
                ? "Apple Color Emoji · macOS"
                : Lang.shared.t("未找到 Apple Color Emoji", "Apple Color Emoji not found"),
            note: Lang.shared.t("弱信号，只作参考", "Weak signal, reference only")
        )
    }
}
