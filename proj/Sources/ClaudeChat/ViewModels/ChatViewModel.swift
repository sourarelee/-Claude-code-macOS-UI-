import SwiftUI

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isRunning = false
    @Published var streamingText = ""
    @Published var statusText = ""
    @Published var permissionMode = "default"

    private(set) var conversation: Conversation
    private let service = ClaudeService()
    private let store = ConversationStore.shared
    var onConversationUpdated: ((Conversation) -> Void)?

    private var flushTimer: Timer?
    private var pendingText = ""

    init(conversation: Conversation) {
        // 从磁盘加载最新数据
        let loaded = Self.loadFresh(id: conversation.id)
        self.conversation = loaded ?? conversation
        self.messages = self.conversation.messages
        print("[ChatVM] init: \(self.conversation.title)(\(self.conversation.id.uuidString.prefix(8))) → \(self.messages.count) 条消息")
        print("[ChatVM]   folder=\(self.conversation.folderPath) sessionId=\(self.conversation.sessionId.prefix(16))")
        if loaded == nil {
            store.updateConversation(conversation)
        }
    }

    private static func loadFresh(id: UUID) -> Conversation? {
        ConversationStore.shared.loadConversation(id: id)
    }

    deinit {
        print("[ChatVM] deinit: \(conversation.title)(\(conversation.id.uuidString.prefix(8)))")
        service.stop()
        flushTimer?.invalidate()
    }

    func send(_ text: String) {
        let msg = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !msg.isEmpty, !isRunning else { return }

        guard ClaudeService.isAvailable else {
            statusText = "未找到 Claude Code，请先安装（详见欢迎页指引）"
            return
        }

        saveUserMessage(msg)
        streamingText = ""
        pendingText = ""
        statusText = ""
        isRunning = true

        let sid = conversation.sessionId
        let resume = messages.count > 1
        let dir = conversation.folderPath.isEmpty ? nil : conversation.folderPath
        let mode = permissionMode

        print("[ChatVM] send: \(conversation.title)(\(conversation.id.uuidString.prefix(8))) resume=\(resume) dir=\(dir ?? "无")")

        service.send(
            sessionId: sid,
            message: msg,
            workingDirectory: dir,
            permissionMode: mode,
            resume: resume,
            onEvent: { [weak self] event in
                guard let self = self else { return }
                switch event {
                case .text(let chunk):
                    self.pendingText += chunk
                    self.scheduleUpdate()
                case .status(let text):
                    self.statusText = text
                case .done:
                    self.finishResponse()
                }
            }
        )
    }

    private func scheduleUpdate() {
        flushTimer?.invalidate()
        flushTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: false) { [weak self] _ in
            DispatchQueue.main.async { self?.streamingText = self?.pendingText ?? "" }
        }
    }

    private func finishResponse() {
        flushTimer?.invalidate()
        flushTimer = nil
        streamingText = pendingText
        let cleaned = pendingText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleaned.isEmpty {
            let am = Message(role: .assistant, content: cleaned)
            messages.append(am)
            var updated = conversation
            updated.messages = messages
            updated.updatedAt = Date()
            store.updateConversation(updated)
            conversation = updated
            onConversationUpdated?(updated)
        }
        pendingText = ""
        streamingText = ""
        statusText = ""
        isRunning = false
    }

    func stop() {
        service.stop()
        finishResponse()
    }

    private func saveUserMessage(_ text: String) {
        let msg = Message(role: .user, content: text)
        messages.append(msg)
        var updated = conversation
        updated.messages = messages
        updated.updatedAt = Date()
        if updated.title.isEmpty { updated.title = String(text.prefix(50)) }
        store.updateConversation(updated)
        conversation = updated
        onConversationUpdated?(updated)
    }
}
