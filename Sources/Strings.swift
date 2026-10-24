//
//  Strings.swift
//  中英双语：全局语言状态 + 界面词条 + 信号元数据双语
//

import SwiftUI

/// 当前界面语言。auto = 跟随系统，顶栏按钮可在 中 / EN 之间切换并持久化。
enum L: String {
    case zh, en
}

final class Lang: ObservableObject {
    static let shared = Lang()

    @AppStorage("cnd.lang") var raw: String = "auto"

    var current: L {
        switch raw {
        case "zh": return .zh
        case "en": return .en
        default:
            let head = Locale.preferredLanguages.first ?? ""
            return head.lowercased().hasPrefix("zh") ? .zh : .en
        }
    }

    var isZh: Bool { current == .zh }

    func toggle() {
        raw = (current == .zh) ? "en" : "zh"
        objectWillChange.send()
    }

    /// 界面取词：lang.t("中文", "English")
    func t(_ zh: String, _ en: String) -> String {
        current == .zh ? zh : en
    }
}

// MARK: - 信号元数据双语（id -> 名称 / 说明 / 角标）

struct SignalI18n {
    let name: (zh: String, en: String)
    let desc: (zh: String, en: String)
    let note: (zh: String, en: String)?
}

enum SignalsI18n {
    static let table: [String: SignalI18n] = [
        "timezone": SignalI18n(
            name: ("系统时区", "System timezone"),
            desc: ("Claude Code 直接读的就是这一个值，和 Asia/Shanghai、Asia/Urumqi 等中国时区比对。",
                   "The exact value Claude Code reads; compared against Asia/Shanghai, Asia/Urumqi and other China timezones."),
            note: ("Claude 同款", "Same as Claude")),
        "language": SignalI18n(
            name: ("系统语言", "System language"),
            desc: ("取 AppleLanguages 的首位；zh-Hans / zh-CN 得分最高，中文排在后面也算弱信号。",
                   "First entry of AppleLanguages; zh-Hans / zh-CN score highest, Chinese later in the list is a weak signal."),
            note: nil),
        "cjkFonts": SignalI18n(
            name: ("中文字体", "CJK fonts"),
            desc: ("在本机字体库里找苹方、宋体、黑体等简繁中文字体 —— 装没装一眼就能看出来。",
                   "Searches PingFang, Songti, Heiti and other CJK fonts in the local registry — installed or not, it shows at a glance."),
            note: nil),
        "vendorFonts": SignalI18n(
            name: ("国产厂商字体", "Vendor fonts"),
            desc: ("MiSans、鸿蒙黑体、OPPO Sans、方正字库这些基本只会随国产设备或软件一起出现。",
                   "MiSans, HarmonyOS Sans, OPPO Sans, Founder etc. usually appear only with CN devices or apps."),
            note: ("强信号", "Strong")),
        "network": SignalI18n(
            name: ("网络出口 / IP 暴露", "Egress / IP exposure"),
            desc: ("枚举本机网卡地址，并（可选）查询公网出口 IP 与国家归属。浏览器端对应的是 WebRTC 泄露。",
                   "Enumerates local NIC addresses and optionally looks up the public egress IP and country; the browser analog is a WebRTC leak."),
            note: ("WebRTC 同款", "WebRTC-like")),
        "browserApps": SignalI18n(
            name: ("国产浏览器 / WebView", "CN browsers / WebViews"),
            desc: ("扫描已安装的微信、QQ、钉钉、夸克、UC、百度等应用 —— 它们都是内嵌 WebKit 的常客。",
                   "Scans installed WeChat, QQ, DingTalk, Quark, UC, Baidu etc. — all common WebKit hosts."),
            note: nil),
        "device": SignalI18n(
            name: ("国产品牌设备", "CN-brand device"),
            desc: ("读取 hw.model 机型标识，匹配鸿蒙、华为、小米、OPPO、vivo 等厂商。",
                   "Reads the hw.model identifier and matches HarmonyOS, Huawei, Xiaomi, OPPO, vivo and others."),
            note: nil),
        "localeSetting": SignalI18n(
            name: ("Intl 区域设置", "Intl locale"),
            desc: ("系统用于日期 / 数字格式化的区域，和时区是两条独立的证据。",
                   "The region used for date/number formatting — separate evidence from the timezone."),
            note: nil),
        "utcOffset": SignalI18n(
            name: ("时区偏移量", "UTC offset"),
            desc: ("秒级偏移是否为 UTC+8，以及是否全年都不带夏令时。",
                   "Whether the offset is UTC+8 year-round with no daylight saving."),
            note: nil),
        "emoji": SignalI18n(
            name: ("表情符号渲染风格", "Emoji style"),
            desc: ("由系统与字形渲染栈推断 —— macOS 上恒定是 Apple Color Emoji，参考价值有限。",
                   "Inferred from the system glyph stack — always Apple Color Emoji on macOS, limited value."),
            note: ("弱相关", "Weak"))
    ]
}

extension Signal {
    private var i18n: SignalI18n? { SignalsI18n.table[id] }

    var nameLocal: String {
        guard let i = i18n else { return name }
        return Lang.shared.isZh ? i.name.zh : i.name.en
    }

    var descLocal: String {
        guard let i = i18n else { return desc }
        return Lang.shared.isZh ? i.desc.zh : i.desc.en
    }

    var noteLocal: String? {
        guard let i = i18n, let n = i.note else { return note }
        return Lang.shared.isZh ? n.zh : n.en
    }
}
