import SwiftUI
import UniformTypeIdentifiers

struct FileDropModifier: ViewModifier {
    let folderPath: String
    @State private var isTargeted = false
    @State private var toast = ""

    func body(content: Content) -> some View {
        content
            .overlay(dropOverlay)
            .overlay(toastOverlay, alignment: .top)
            .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
                handleDrop(providers)
                return true
            }
    }

    @ViewBuilder
    private var dropOverlay: some View {
        if isTargeted {
            ZStack {
                RoundedRectangle(cornerRadius: Design.Radius.lg)
                    .fill(Design.Color.accent.opacity(0.08))
                    .overlay(RoundedRectangle(cornerRadius: Design.Radius.lg)
                        .stroke(Design.Color.accent, style: StrokeStyle(lineWidth: 2, dash: [8, 4])))
                VStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Design.Color.accent)
                    Text("松开以添加文件到项目")
                        .font(Design.Font.heading)
                        .foregroundColor(Design.Color.accent)
                }
            }
            .padding(Design.Spacing.xl)
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var toastOverlay: some View {
        if !toast.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                Text(toast).font(Design.Font.body)
            }
            .padding(.horizontal, Design.Spacing.lg)
            .padding(.vertical, Design.Spacing.sm)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: Design.Radius.md))
            .shadow(radius: 4)
            .padding(.top, Design.Spacing.xl)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        guard !folderPath.isEmpty else {
            showToast("请先选择项目文件夹")
            return
        }
        let fm = FileManager.default
        var copied: [String] = []
        var failed: [String] = []
        let group = DispatchGroup()

        for p in providers {
            group.enter()
            p.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                defer { group.leave() }
                guard let data = item as? Data,
                      let path = String(data: data, encoding: .utf8),
                      let url = URL(string: path) else { return }
                let name = url.lastPathComponent
                var dest = URL(fileURLWithPath: folderPath).appendingPathComponent(name)
                var i = 1
                while fm.fileExists(atPath: dest.path) {
                    let base = dest.deletingPathExtension().lastPathComponent
                    let ext = dest.pathExtension
                    let newName = ext.isEmpty ? "\(base) \(i)" : "\(base) \(i).\(ext)"
                    dest = URL(fileURLWithPath: folderPath).appendingPathComponent(newName)
                    i += 1
                }
                do {
                    try fm.copyItem(at: url, to: dest)
                    DispatchQueue.main.async { copied.append(name) }
                } catch {
                    DispatchQueue.main.async { failed.append(name) }
                }
            }
        }

        group.notify(queue: .main) {
            var msg = ""
            if !copied.isEmpty { msg = "已添加: \(copied.joined(separator: ", "))" }
            if !failed.isEmpty { msg += (msg.isEmpty ? "" : "  ") + "失败: \(failed.joined(separator: ", "))" }
            if msg.isEmpty { msg = "未识别到文件" }
            showToast(msg)
        }
    }

    private func showToast(_ msg: String) {
        withAnimation(.easeInOut(duration: 0.2)) { toast = msg }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            withAnimation(.easeInOut(duration: 0.2)) { toast = "" }
        }
    }
}

extension View {
    func fileDropTarget(folderPath: String) -> some View {
        modifier(FileDropModifier(folderPath: folderPath))
    }
}
