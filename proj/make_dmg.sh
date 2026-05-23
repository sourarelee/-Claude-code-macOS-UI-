#!/bin/bash
set -e

APP_NAME="见一面"
DMG_NAME="${APP_NAME}.dmg"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STAGING_DIR=$(mktemp -d)
BACKGROUND_NAME="dmg_background.png"

echo "==> 生成背景图片..."
python3 "${SCRIPT_DIR}/make_dmg_background.py"

echo "==> 创建临时目录: $STAGING_DIR"

# 复制 .app
cp -R "${SCRIPT_DIR}/${APP_NAME}.app" "$STAGING_DIR/"

# 创建 Applications 符号链接
ln -s /Applications "$STAGING_DIR/Applications"

# 创建 .background 目录并复制背景图
mkdir "$STAGING_DIR/.background"
cp "${SCRIPT_DIR}/${BACKGROUND_NAME}" "$STAGING_DIR/.background/"

echo "==> 打包 DMG..."

# 删除旧 DMG
rm -f "${SCRIPT_DIR}/${DMG_NAME}"

# 使用压缩格式创建 DMG（预留空间给背景图和 AppleScript 布局）
hdiutil create \
  -volname "${APP_NAME}" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDRW \
  -fs HFS+ \
  -size 100m \
  "${SCRIPT_DIR}/tmp_${DMG_NAME}"

# 挂载 DMG
DEVICE=$(hdiutil attach -readwrite -noverify -noautoopen "${SCRIPT_DIR}/tmp_${DMG_NAME}" | egrep '^/dev/' | sed 1q | awk '{print $1}')
MOUNT_POINT="/Volumes/${APP_NAME}"

echo "==> 设置 DMG 布局..."

# 用 AppleScript 设置窗口属性、背景和图标位置
osascript <<EOF
tell application "Finder"
  tell disk "${APP_NAME}"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 200, 740, 580}
    set theViewOptions to the icon view options of container window
    set arrangement of theViewOptions to not arranged
    set icon size of theViewOptions to 72
    set background picture of theViewOptions to file ".background:${BACKGROUND_NAME}"

    -- 等待窗口创建
    delay 0.5

    -- 设置 .app 的位置
    set position of item "${APP_NAME}.app" of container window to {120, 190}
    -- 设置 Applications 链接的位置
    set position of item "Applications" of container window to {370, 190}

    -- 隐藏背景文件夹
    set extension hidden of item ".background" of container window to true

    update without registering applications
    delay 0.5
    close
  end tell
end tell
EOF

# 等待 Finder 完成
sleep 1

echo "==> 最终化 DMG..."

# 先转换为只读压缩格式
hdiutil detach "$DEVICE" 2>/dev/null
hdiutil convert "${SCRIPT_DIR}/tmp_${DMG_NAME}" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "${SCRIPT_DIR}/${DMG_NAME}"

# 清理
rm -f "${SCRIPT_DIR}/tmp_${DMG_NAME}"
rm -rf "$STAGING_DIR"

echo "==> 完成: ${DMG_NAME}"
