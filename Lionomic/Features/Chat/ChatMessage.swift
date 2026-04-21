import Foundation

/// UI-facing chat roles. Kept separate from `AIMessage.Role` so the chat
/// feature doesn't couple to the service layer's wire type.
enum ChatRole: String, Hashable, Sendable {
    case user
    case assistant
}

/// A single message rendered in the chat transcript.
struct ChatMessage: Identifiable, Hashable, Sendable {
    let id: UUID
    let role: ChatRole
    let content: String

    init(id: UUID = UUID(), role: ChatRole, content: String) {
        self.id = id
        self.role = role
        self.content = content
    }
}
