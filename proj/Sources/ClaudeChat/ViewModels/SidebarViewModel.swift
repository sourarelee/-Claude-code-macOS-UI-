import SwiftUI
import AppKit

@MainActor
final class SidebarViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var selectedId: UUID?
    private let store = ConversationStore.shared

    init() { reload() }

    func reload() {
        conversations = store.loadConversations()
        print("[SidebarVM] 重载: \(conversations.count) 个对话")
        for c in conversations {
            print("[SidebarVM]   - \(c.title)(\(c.id.uuidString.prefix(8))) folder=\(c.folderPath)")
        }
    }

    func createConversation(folderPath: String) -> Conversation {
        let conv = Conversation(title: URL(fileURLWithPath: folderPath).lastPathComponent, folderPath: folderPath)
        conversations.insert(conv, at: 0)
        store.updateConversation(conv)
        selectedId = conv.id
        print("[SidebarVM] 新建: \(conv.title)(\(conv.id.uuidString.prefix(8))) folder=\(conv.folderPath)")
        return conv
    }

    func pickFolderAndCreate() -> Conversation? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true; panel.canChooseFiles = false; panel.canCreateDirectories = true
        panel.prompt = "选择此文件夹"; panel.message = "选择一个工作目录"
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        return createConversation(folderPath: url.path)
    }

    func deleteConversation(id: UUID) {
        store.deleteConversation(id: id)
        conversations.removeAll { $0.id == id }
        if selectedId == id { selectedId = conversations.first?.id }
    }

    func renameConversation(id: UUID, title: String) {
        store.renameConversation(id: id, title: title)
        if let i = conversations.firstIndex(where: { $0.id == id }) { conversations[i].title = title }
    }

    /// 消息变动后更新侧边栏内存中的对话对象
    func refreshConversation(_ conv: Conversation) {
        if let i = conversations.firstIndex(where: { $0.id == conv.id }) {
            conversations[i] = conv
        }
    }
}
