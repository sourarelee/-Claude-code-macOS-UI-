import SwiftUI
final class AppSettings: ObservableObject {
    @Published var themeMode: ThemeMode { didSet { save() } }
    enum ThemeMode: String, Codable, CaseIterable { case system, light, dark }
    private let key = "claude_chat_theme"
    init() {
        if let raw = UserDefaults.standard.string(forKey: key),
           let mode = ThemeMode(rawValue: raw) { self.themeMode = mode }
        else { self.themeMode = .system }
    }
    private func save() { UserDefaults.standard.set(themeMode.rawValue, forKey: key) }
    var colorScheme: ColorScheme? {
        switch themeMode { case .system: nil; case .light: .light; case .dark: .dark }
    }
}
