import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    var body: some View {
        TabView {
            GeneralTab(settings: settings).tabItem { Label("通用", systemImage: "gearshape") }
            AboutTab().tabItem { Label("关于", systemImage: "info.circle") }
        }
    }
}

struct GeneralTab: View {
    @ObservedObject var settings: AppSettings
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("外观").font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary).padding(.horizontal, Design.Spacing.xl).padding(.top, Design.Spacing.xl)
            VStack(spacing: 0) {
                ForEach(AppSettings.ThemeMode.allCases, id: \.self) { mode in
                    Button(action: { settings.themeMode = mode }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) { Text(modeName(mode)).font(Design.Font.body); Text(modeDesc(mode)).font(Design.Font.caption).foregroundColor(.secondary) }
                            Spacer()
                            if settings.themeMode == mode { Image(systemName: "checkmark").font(.system(size: 12, weight: .semibold)).foregroundColor(Design.Color.accent) }
                        }.padding(.horizontal, Design.Spacing.xl).padding(.vertical, Design.Spacing.md).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                    if mode != AppSettings.ThemeMode.allCases.last { Divider().padding(.leading, Design.Spacing.xl).opacity(0.4) }
                }
            }.padding(.top, Design.Spacing.sm)
            Spacer()
        }
    }
    private func modeName(_ m: AppSettings.ThemeMode) -> String { m == .system ? "跟随系统" : m == .light ? "浅色模式" : "深色模式" }
    private func modeDesc(_ m: AppSettings.ThemeMode) -> String { m == .system ? "自动匹配 macOS 外观" : m == .light ? "始终使用浅色主题" : "始终使用深色主题" }
}

struct AboutTab: View {
    var body: some View {
        VStack(spacing: Design.Spacing.lg) {
            Spacer()
            ZStack { Circle().fill(Design.Color.accentBg).frame(width: 64, height: 64); Image(systemName: "sparkles").font(.system(size: 26, weight: .light)).foregroundColor(Design.Color.accent) }
            Text("见一面").font(.system(size: 18, weight: .medium))
            Text("版本 1.0").font(Design.Font.caption).foregroundColor(.secondary)
            Text("Claude Code 的优雅 macOS 界面\n让 AI 编码体验更舒适。").font(Design.Font.caption).foregroundColor(.secondary).multilineTextAlignment(.center)
            Spacer()
        }.frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
