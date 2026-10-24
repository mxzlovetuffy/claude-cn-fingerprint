# Claude 中国用户检测器 · CN Fingerprint Detector (macOS)

一个原生 macOS 小工具：把十项区域与网络指纹加权成 0–100 的风险分，
让你先看清楚自己的机器到底向外界暴露了什么。**所有检测都在本机完成。**

A native macOS utility that scores ten region / network fingerprints into a
0–100 risk number, so you can see exactly what your machine exposes.
**Every check runs locally on your machine.**

---

## 中文说明

### 这是什么

界面采用 macOS 26 的 Liquid Glass（`glassEffect` / `NSVisualEffectView`），
窗口本身就是一块半透明磨砂玻璃。主界面环形分数旁的 `Today's date` 是
**真实本机时间**，每秒跳动。

三个标签页：

- **检测**：左边环形分（按权重分角度，红 = 命中、黄 = 弱命中、青 = 未命中），
  右边十张信号卡；环下那条 `PROMPT · 实时` 模拟 Claude 每次请求都会带上的日期行。
- **原理**：那条 system prompt 长什么样、软连字符和撇号变体是怎么藏进几个 bit 的。
- **降分**：按权重从高到低的五步操作建议。

### 检测原理（整理自网络公开讨论，非官方）

> ⚠️ 以下原理整理自**网络上流传的公开逆向分析与社区讨论**，
> **不是 Anthropic 官方说明**，Anthropic 从未公开承认过该机制，真实性请自行判断。

据这些公开分析：当 Claude Code 通过 `ANTHROPIC_BASE_URL` 指向第三方中转端点时，
它会读取操作系统时区与中转 hostname，再把判定结果用 **Unicode 隐写术**藏进
system prompt 里 `Today's date` 那一行——肉眼完全分不出差别的几个 Unicode 变体：

| 字符 | 码位 | 角色 |
| --- | --- | --- |
| `’` | U+2019 | 常规右单引号 |
| `ʹ` | U+02B9 | 修饰字母撇号 |
| `ʼ` | U+02BC | 修饰字母撇（送气符号） |
| `‑` | U+2011 | 不换行连字符（日期分隔符变体） |

四种几乎一样的撇号 × 两种连字符，肉眼分辨不出，却足以编出几个 bit 的信息。

网页读不到 Claude Code 能读的全部信息，但关键信号是同一批。本工具在**系统层面**
读取同一个时区，再叠加语言、字体、网络出口、国产 App、机型、区域、偏移、emoji
共十项指纹，加权得分。单项归一化到 0–1，**≥ 0.25 记为命中**；
分档：低 0–30、中 31–60、高 61–100。

### 十项信号与权重

| 信号 | 权重 | 怎么测的（本机 API） |
| --- | --- | --- |
| 系统时区 | 24 | `TimeZone.current.identifier`，比对 Asia/Shanghai 等中国时区 |
| 系统语言 | 18 | `Locale.preferredLanguages` 首位是否 zh-Hans / zh-CN |
| 中文字体 | 14 | `CTFontManagerCopyAvailableFontFamilyNames()` 里找苹方、宋体、黑体 |
| 国产厂商字体 | 10 | MiSans、鸿蒙黑体、OPPO Sans、方正等 |
| 网络出口 / IP | 10 | `getifaddrs` 枚举本机网卡 + **可选**查询公网出口归属 |
| 国产浏览器 / WebView | 8 | 已安装的微信、QQ、钉钉、夸克、UC、百度等 |
| 国产品牌设备 | 6 | `sysctl hw.model` 机型标识 |
| Intl 区域设置 | 4 | `Locale.current` 的 region 与日历 |
| 时区偏移量 | 3 | 现在、1 月、7 月是否都固定 UTC+8、无夏令时 |
| 表情符号渲染风格 | 3 | 字形栈推断，弱信号 |

合计 100 分。「中文字体」和「国产厂商字体」是两项独立信号——前者说明系统里有中文，
后者说明这台机器大概率是国产设备或装过国产软件，所以单独给了 10 分。

### 隐私声明：本 App 不获取你的隐私

- **不上传任何检测结果**：报告只在本机生成，复制报告也只是写进你自己的剪贴板。
- **不写日志、不写 cookie、不建数据库、不读取你的文件内容。**
- 十项里的九项（时区、语言、字体、App 列表、机型、区域、偏移、emoji）
  **全程零网络请求**，纯本机系统 API 读取。
- 唯一可能的对外请求是「公网出口探测」：默认开启时会访问一次
  `https://ipapi.co/json/`（失败回退 `https://ipinfo.io/json`），
  仅用于读出你当前公网出口 IP 的国家归属，**不携带任何本机标识、不附带 User-Agent 之外的信息**。
  在主界面左下角把「公网出口探测」开关关掉后，**本 App 完全离线，零外发**。

### 结果不能代表实际

- 本工具只是一个**隐私自检与指纹教育玩具**，分数是作者按公开讨论**自行加权**的，
  **不保证与 Anthropic 的真实风控模型一致**，也不代表你会被封号、降级或限制使用。
- 真实风控由服务端综合更多因素（账号、账单、历史行为、网络路径等）决定，
  本机指纹只是其中很小的一部分。**不要把本工具的分数当作任何官方判定。**

### macOS 未签名 App 如何运行

本 App **没有 Apple Developer ID 签名，也没有公证（notarization）**，
下载后首次打开会被 Gatekeeper 拦住，这是正常现象，不是病毒。任选一种方式放行：

**方式一：右键打开（推荐）**

1. 在 Finder 里找到 `Claude 中国用户检测器.app`
2. **右键（或按住 Control 点按）→ 选择「打开」**
3. 弹窗里再点「打开」，之后就能正常双击启动。

**方式二：命令行移除隔离属性**

```bash
xattr -dr com.apple.quarantine "Claude 中国用户检测器.app"
```

执行后直接双击即可。

> 如果提示「无法验证开发者」，说明隔离属性还在，重新执行方式二即可。
> 把 App 拖进 `/Applications` 前先放行，避免启动台再次拦截。

### 构建

仓库只含源码，自行构建需要 Xcode（CommandLineTools 的 SDK 版本对不上，会报
`this SDK is not supported by the compiler`）：

```bash
./build.sh
# 或指定 Xcode：
XCODE=/path/to/Xcode.app/Contents/Developer ./build.sh
```

构建产物为 `dist/Claude 中国用户检测器.app`。要求 macOS 26 或更高（Liquid Glass 从 26 开始提供）。

```
Sources/
  App.swift            入口、窗口外观（透明 + fullSizeContentView）
  Theme.swift          颜色、风险分档、玻璃背景与修饰
  Detector.swift       十项探测
  DetectorModel.swift  扫描流程、计分、复制报告
  Views.swift          主界面、分数环、信号卡、原理页、降分页
```

---

## English

### What it is

A native SwiftUI macOS app (macOS 26 Liquid Glass) that scores ten local
region/network fingerprints into a 0–100 risk number. Three tabs:
**Scan** (ring score + ten signal cards), **Mechanism** (the prompt
steganography explained), **Mitigation** (weighted steps to lower the score).

### How detection works (from public online discussion, NOT official)

> ⚠️ The mechanism below is compiled from **public reverse-engineering write-ups
> and community discussions circulating online**. It is **NOT an official
> Anthropic statement**; Anthropic has never confirmed it. Judge its truth
> for yourself.

According to these public analyses, when Claude Code points
`ANTHROPIC_BASE_URL` at a third-party relay, it may read the OS timezone and
the relay hostname, then encode the verdict into the `Today's date` line of the
system prompt using **Unicode steganography** — near-identical glyph variants:

| Glyph | Code point | Role |
| --- | --- | --- |
| `’` | U+2019 | Right single quote |
| `ʹ` | U+02B9 | Modifier letter prime |
| `ʼ` | U+02BC | Modifier letter apostrophe |
| `‑` | U+2011 | Non-breaking hyphen (date separator variant) |

Four look-alike apostrophes × two hyphens are invisible to the eye but can
encode a few bits. A web page cannot read everything Claude Code can, but the
key signals overlap; this app reads the same timezone at the OS level and adds
nine more local fingerprints. Per-item ratio ≥ 0.25 counts as a hit;
bands: Low 0–30, Medium 31–60, High 61–100.

### Signals & weights

| Signal | Weight | How it is read (local API) |
| --- | --- | --- |
| System timezone | 24 | `TimeZone.current.identifier` vs China timezones |
| System language | 18 | First entry of `Locale.preferredLanguages` |
| CJK fonts | 14 | PingFang / Songti / Heiti in the local font registry |
| Vendor fonts | 10 | MiSans, HarmonyOS Sans, OPPO Sans, Founder, etc. |
| Egress / IP | 10 | `getifaddrs` NIC enumeration + *optional* public IP lookup |
| CN browsers / WebViews | 8 | Installed WeChat, QQ, DingTalk, Quark, UC, Baidu, etc. |
| CN-brand device | 6 | `sysctl hw.model` model string |
| Intl locale | 4 | `Locale.current` region & calendar |
| UTC offset | 3 | Fixed UTC+8 year-round, no DST |
| Emoji style | 3 | Glyph stack inference, weak signal |

### Privacy: this app does not harvest your data

- **No results are uploaded.** The report is generated locally; "copy" only
  writes to your own clipboard.
- **No logs, no cookies, no database, no reading of your files.**
- Nine of ten signals (timezone, language, fonts, app list, model, locale,
  offset, emoji) make **zero network requests** via local system APIs only.
- The only optional outbound call is the egress probe: it hits
  `https://ipapi.co/json/` (fallback `https://ipinfo.io/json`) once to read
  your public egress country, carrying nothing beyond the request itself.
  Turn the **Egress probe** toggle off in the UI and the app goes
  **fully offline — zero outbound traffic.**

### The result is NOT authoritative

- This is a **self-check and fingerprinting education toy**. The weights are
  the author's own, derived from public discussion; the score
  **does NOT match Anthropic's real risk model** and does not mean you will be
  banned, rate-limited or restricted.
- Real risk scoring happens server-side across account, billing, history and
  network path; local fingerprints are only a small part. **Treat the number as
  nothing official.**

### Running an unsigned app on macOS

This app has **no Apple Developer ID signature and no notarization**, so
Gatekeeper blocks it on first launch — that is normal, it is not malware.

**Option 1: Right-click Open (recommended)**

1. Find `Claude 中国用户检测器.app` in Finder.
2. **Right-click (or Control-click) → Open**.
3. Click **Open** in the dialog; double-click works afterwards.

**Option 2: Strip the quarantine flag in Terminal**

```bash
xattr -dr com.apple.quarantine "Claude 中国用户检测器.app"
```

Then double-click to launch. If you still see "cannot verify the developer",
re-run Option 2.

### Build

This repository contains source only. From source you need Xcode (Command Line
Tools SDK is too old):

```bash
./build.sh
```

The script produces `dist/Claude 中国用户检测器.app`. Requires macOS 26+
(Liquid Glass).

---

## License

For privacy education and self-checking only. Use at your own risk.
