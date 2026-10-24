#!/bin/bash
# 构建 Claude 中国用户检测器.app
# 用法: ./build.sh
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="Claude 中国用户检测器"
APP="dist/${APP_NAME}.app"
# 需要 Xcode（不是 CommandLineTools）：Liquid Glass 的 SDK 要 26.0+
XCODE="${XCODE:-$(ls -d /Applications/Xcode*.app/Contents/Developer 2>/dev/null | tail -1)}"
SDK="$(ls -d "$XCODE"/Platforms/MacOSX.platform/Developer/SDKs/MacOSX*.sdk | tail -1)"
SWIFTC="$XCODE/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"

echo "==> 编译"
mkdir -p build
"$SWIFTC" -parse-as-library -O -swift-version 5 -disable-sandbox \
  -target arm64-apple-macosx26.0 -sdk "$SDK" \
  -module-cache-path "$PWD/build/ModuleCache" \
  Sources/*.swift -o build/CNDetector

echo "==> 组装 bundle"
# 旧 bundle 可能被系统占位（rm 报 Resource deadlock），先删，失败则改名挪走
if [ -e "$APP" ]; then
  rm -rf "$APP" 2>/dev/null || mv "$APP" "/tmp/cnd_old_$$.app" 2>/dev/null || true
fi
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp build/CNDetector "$APP/Contents/MacOS/CNDetector"
printf 'APPL????' > "$APP/Contents/PkgInfo"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>${APP_NAME}</string>
  <key>CFBundleDisplayName</key><string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key><string>dev.local.claude-cn-detector</string>
  <key>CFBundleExecutable</key><string>CNDetector</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>26.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>本地检测，不上传任何数据。</string>
</dict>
</plist>
PLIST

echo "==> 图标"
if [ -d assets/AppIcon.iconset ]; then
  iconutil -c icns assets/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
fi

echo "==> 签名"
xattr -cr "$APP"
codesign --force --deep --sign - "$APP"

echo "==> 完成: $APP"
