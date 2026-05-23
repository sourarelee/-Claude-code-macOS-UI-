import SwiftUI

@main
struct 见一面App: App {
    @StateObject private var settings = AppSettings()
    var body: some Scene {
        WindowGroup {
            ContentView().environmentObject(settings).preferredColorScheme(settings.colorScheme).background(Design.Color.chatBg)
        }
        .windowStyle(.hiddenTitleBar).windowToolbarStyle(.unified)
        .defaultSize(width: 1000, height: 700)
        .commands {
            SidebarCommands()
            CommandGroup(replacing: .appInfo) {
                Button("关于 见一面") { NSApplication.shared.orderFrontStandardAboutPanel() }
            }
        }
        Settings { SettingsView().environmentObject(settings).frame(width: 480, height: 320) }
    }
}
