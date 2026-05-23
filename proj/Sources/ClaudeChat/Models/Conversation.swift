import Foundation
struct Conversation: Identifiable, Codable {
    var id: UUID
    var title: String
    var sessionId: String
    var folderPath: String
    var createdAt: Date
    var updatedAt: Date
    var messages: [Message]
    init(id: UUID = UUID(), title: String = "", sessionId: String = UUID().uuidString,
         folderPath: String = "", createdAt: Date = Date(), updatedAt: Date = Date(),
         messages: [Message] = []) {
        self.id = id; self.title = title; self.sessionId = sessionId
        self.folderPath = folderPath; self.createdAt = createdAt
        self.updatedAt = updatedAt; self.messages = messages
    }
}
