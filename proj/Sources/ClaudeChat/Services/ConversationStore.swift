import Foundation

final class ConversationStore {
    static let shared = ConversationStore()
    private let baseURL: URL
    private let indexURL: URL
    private let fm = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        baseURL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".claude/conversations")
        indexURL = baseURL.appendingPathComponent("index.json")
        do { try fm.createDirectory(at: baseURL, withIntermediateDirectories: true) }
        catch { print("[Store] 无法创建目录: \(error)") }
    }

    func loadConversations() -> [Conversation] {
        let idx = loadIndex()
        var convs: [Conversation] = []
        for meta in idx.conversations {
            if let c = loadConversation(id: meta.id) { convs.append(c) }
        }
        return convs.sorted { $0.updatedAt > $1.updatedAt }
    }

    /// 公开方法：按 ID 加载单个对话（始终从磁盘读取最新）
    func loadConversation(id: UUID) -> Conversation? {
        let mf = msgsFile(id)
        guard fm.fileExists(atPath: mf.path) else { return nil }
        do {
            let data = try Data(contentsOf: mf)
            let msgs = try decoder.decode([Message].self, from: data)
            let m = loadIndex().conversations.first { $0.id == id }
            let conv = Conversation(id: id, title: m?.title ?? "", sessionId: m?.sessionId ?? id.uuidString,
                                    folderPath: m?.folderPath ?? "", createdAt: m?.createdAt ?? Date(),
                                    updatedAt: m?.updatedAt ?? Date(), messages: msgs)
            print("[Store] 加载对话: \(conv.title)(\(id.uuidString.prefix(8))) → \(msgs.count) 条")
            return conv
        } catch {
            print("[Store] 加载失败 \(id.uuidString.prefix(8)): \(error)")
            return nil
        }
    }

    func createConversation(folderPath: String) -> Conversation {
        let name = URL(fileURLWithPath: folderPath).lastPathComponent
        let conv = Conversation(title: name, folderPath: folderPath)
        saveConversation(conv)
        var idx = loadIndex()
        idx.conversations.insert(Meta(conv), at: 0)
        saveIndex(idx)
        print("[Store] 创建: \(conv.title)(\(conv.id.uuidString.prefix(8)))")
        return conv
    }

    func updateConversation(_ conv: Conversation) {
        saveConversation(conv)
        var idx = loadIndex()
        if let i = idx.conversations.firstIndex(where: { $0.id == conv.id }) {
            idx.conversations[i] = Meta(conv)
        } else {
            idx.conversations.insert(Meta(conv), at: 0)
        }
        saveIndex(idx)
        print("[Store] 更新: \(conv.title)(\(conv.id.uuidString.prefix(8))) → \(conv.messages.count) 条")
    }

    func deleteConversation(id: UUID) {
        try? fm.removeItem(at: dir(id))
        var idx = loadIndex()
        idx.conversations.removeAll { $0.id == id }
        saveIndex(idx)
    }

    func renameConversation(id: UUID, title: String) {
        if var c = loadConversation(id: id) { c.title = title; updateConversation(c) }
    }

    private func dir(_ id: UUID) -> URL { baseURL.appendingPathComponent(id.uuidString) }
    private func msgsFile(_ id: UUID) -> URL { dir(id).appendingPathComponent("messages.json") }

    private func saveConversation(_ conv: Conversation) {
        do {
            try fm.createDirectory(at: dir(conv.id), withIntermediateDirectories: true)
            let data = try encoder.encode(conv.messages)
            try data.write(to: msgsFile(conv.id), options: .atomic)
        } catch {
            print("[Store] 保存失败 \(conv.id.uuidString.prefix(8)): \(error)")
        }
    }

    private func loadIndex() -> Index_ {
        guard fm.fileExists(atPath: indexURL.path) else { return Index_() }
        do {
            let data = try Data(contentsOf: indexURL)
            return try decoder.decode(Index_.self, from: data)
        } catch {
            print("[Store] 加载索引失败: \(error)")
            return Index_()
        }
    }

    private func saveIndex(_ idx: Index_) {
        do {
            let data = try encoder.encode(idx)
            try data.write(to: indexURL, options: .atomic)
        } catch {
            print("[Store] 保存索引失败: \(error)")
        }
    }
}

private struct Index_: Codable { var conversations: [Meta] = [] }
private struct Meta: Codable {
    let id: UUID; var title: String; var sessionId: String; var folderPath: String
    var updatedAt: Date; var createdAt: Date
    init(_ c: Conversation) {
        self.id = c.id; self.title = c.title; self.sessionId = c.sessionId
        self.folderPath = c.folderPath; self.updatedAt = c.updatedAt; self.createdAt = c.createdAt
    }
}
