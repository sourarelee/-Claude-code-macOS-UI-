import SwiftUI
import AppKit

struct SidebarView: View {
    @ObservedObject var viewModel: SidebarViewModel
    let onSelect: (Conversation) -> Void
    @State private var editingId: UUID?; @State private var editTitle = ""; @State private var hoveredId: UUID?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("对话").font(.system(size: 13, weight: .semibold)).foregroundColor(.secondary)
                Spacer()
                Button(action: { if let c = viewModel.pickFolderAndCreate() { onSelect(c) } }) {
                    Image(systemName: "plus").font(.system(size: 13, weight: .medium)).foregroundColor(.secondary)
                }.buttonStyle(.plain).help("新建对话")
            }.padding(.horizontal, Design.Spacing.lg).padding(.vertical, Design.Spacing.md)
            Divider().opacity(0.3)
            if viewModel.conversations.isEmpty {
                VStack(spacing: Design.Spacing.md) {
                    Spacer()
                    Image(systemName: "bubble.left.and.bubble.right").font(.system(size: 24)).foregroundColor(.secondary.opacity(0.3))
                    Text("暂无对话").font(Design.Font.caption).foregroundColor(.secondary.opacity(0.5))
                    Text("点击 + 开始新对话").font(Design.Font.caption).foregroundColor(.secondary.opacity(0.3))
                    Spacer()
                }.frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.conversations) { conv in
                            if editingId == conv.id {
                                TextField("标题", text: $editTitle).textFieldStyle(.plain).font(.system(size: 13))
                                    .padding(.horizontal, Design.Spacing.lg).padding(.vertical, Design.Spacing.sm)
                                    .onSubmit { viewModel.renameConversation(id: conv.id, title: editTitle); editingId = nil }
                                    .onExitCommand { editingId = nil }
                            } else { convRow(conv) }
                        }
                    }.padding(.vertical, Design.Spacing.xs)
                }
            }
        }.background(Design.Color.sidebarBg)
    }

    private func convRow(_ conv: Conversation) -> some View {
        let sel = viewModel.selectedId == conv.id
        let hov = hoveredId == conv.id
        return Button(action: { viewModel.selectedId = conv.id; onSelect(conv) }) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Image(systemName: "folder.fill").font(.system(size: 10)).foregroundColor(sel ? Design.Color.accent : .secondary.opacity(0.5))
                    Text(conv.title.isEmpty ? "未命名" : conv.title).font(.system(size: 13, weight: sel ? .medium : .regular)).lineLimit(1)
                    Spacer()
                }
                if !conv.folderPath.isEmpty {
                    Text(folderShort(conv.folderPath)).font(.system(size: 10.5)).foregroundColor(.secondary.opacity(sel ? 0.7 : 0.5)).lineLimit(1).truncationMode(.middle).padding(.leading, 16)
                }
                Text(relativeDate(conv.updatedAt)).font(.system(size: 10)).foregroundColor(.secondary.opacity(sel ? 0.5 : 0.35)).padding(.leading, 16)
            }.padding(.horizontal, Design.Spacing.lg).padding(.vertical, Design.Spacing.sm + 2).contentShape(Rectangle())
        }.buttonStyle(.plain)
        .background(RoundedRectangle(cornerRadius: Design.Radius.sm)
            .fill(sel ? Design.Color.accentBg : hov ? Color.primary.opacity(0.04) : .clear)
            .padding(.horizontal, Design.Spacing.sm))
        .onHover { hovering in withAnimation(.easeOut(duration: 0.15)) { hoveredId = hovering ? conv.id : nil } }
        .contextMenu { Button("重命名") { editTitle = conv.title; editingId = conv.id }; Divider(); Button("删除", role: .destructive) { viewModel.deleteConversation(id: conv.id) } }
    }

    private func folderShort(_ p: String) -> String { let h = FileManager.default.homeDirectoryForCurrentUser.path; return p.hasPrefix(h) ? "~"+p.dropFirst(h.count) : p }
    private func relativeDate(_ d: Date) -> String {
        let i = Date().timeIntervalSince(d)
        if i < 60 { return "刚刚" }; if i < 3600 { return "\(Int(i/60)) 分钟前" }
        if i < 86400 { return "\(Int(i/3600)) 小时前" }; if i < 604800 { return "\(Int(i/86400)) 天前" }
        let f = DateFormatter(); f.dateFormat = "MM/dd"; return f.string(from: d)
    }
}
