import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var sidebarVM = SidebarViewModel()
    @StateObject private var settings = AppSettings()
    @State private var chatVMs: [UUID: ChatViewModel] = [:]
    @State private var activeId: UUID?
    @State private var claudeMissing = false

    var body: some View {
        NavigationSplitView {
            SidebarView(viewModel: sidebarVM) { conversation in
                select(conversation)
            }
            .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 300)
        } detail: {
            if let id = activeId, let vm = chatVMs[id] {
                ChatView(viewModel: vm).id(id)
                    .overlay(alignment: .top) { if claudeMissing { MissingBanner() } }
            } else {
                WelcomeView(claudeMissing: claudeMissing)
            }
        }
        .preferredColorScheme(settings.colorScheme)
        .environmentObject(settings)
        .frame(minWidth: 900, minHeight: 520)
        .onAppear { claudeMissing = !ClaudeService.isAvailable }
    }

    private func select(_ conversation: Conversation) {
        sidebarVM.selectedId = conversation.id
        activeId = conversation.id
        if chatVMs[conversation.id] == nil {
            let vm = ChatViewModel(conversation: conversation)
            vm.onConversationUpdated = { [weak sidebarVM] c in sidebarVM?.refreshConversation(c) }
            chatVMs[conversation.id] = vm
        }
    }
}

// MARK: - Chat View

struct ChatView: View {
    @ObservedObject var viewModel: ChatViewModel
    @State private var input = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ChatHeader(conversation: viewModel.conversation)
                        ForEach(viewModel.messages) { msg in
                            BubbleView(message: msg).id(msg.id)
                                .padding(.horizontal, Design.Spacing.xl).padding(.vertical, Design.Spacing.sm)
                        }
                        if viewModel.isRunning {
                            if !viewModel.streamingText.isEmpty {
                                StreamingView(text: viewModel.streamingText, status: viewModel.statusText).id("stream")
                                    .padding(.horizontal, Design.Spacing.xl).padding(.vertical, Design.Spacing.sm)
                            } else if !viewModel.statusText.isEmpty {
                                StatusBubble(text: viewModel.statusText).id("status")
                                    .padding(.horizontal, Design.Spacing.xl).padding(.vertical, Design.Spacing.sm)
                            } else {
                                ThinkingBubble().id("think")
                                    .padding(.horizontal, Design.Spacing.xl).padding(.vertical, Design.Spacing.sm)
                            }
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }.padding(.bottom, Design.Spacing.md)
                }
                .onAppear {
                    DispatchQueue.main.async { proxy.scrollTo("bottom", anchor: .bottom) }
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
                .onChange(of: viewModel.streamingText) { _, _ in
                    proxy.scrollTo("stream", anchor: .bottom)
                }
                .onChange(of: viewModel.statusText) { _, _ in
                    proxy.scrollTo("status", anchor: .bottom)
                }
            }
            Divider().opacity(0.3)
            InputBar(text: $input, isRunning: viewModel.isRunning,
                     permissionMode: $viewModel.permissionMode,
                     onSend: { let m = input.trimmingCharacters(in: .whitespacesAndNewlines)
                         guard !m.isEmpty else { return }; input = ""; viewModel.send(m) },
                     onCancel: { viewModel.stop() })
        }
        .background(Design.Color.chatBg)
        .fileDropTarget(folderPath: viewModel.conversation.folderPath)
        .onAppear { focused = true }
    }
}

// MARK: - Chat Header

struct ChatHeader: View {
    let conversation: Conversation
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(conversation.title.isEmpty ? "新对话" : conversation.title).font(Design.Font.heading)
                    if !conversation.folderPath.isEmpty {
                        Text(folderDisplay).font(Design.Font.caption).foregroundColor(.secondary).lineLimit(1)
                    }
                }
                Spacer()
            }.padding(.horizontal, Design.Spacing.xl).padding(.top, Design.Spacing.lg).padding(.bottom, Design.Spacing.sm)
            Divider().padding(.horizontal, Design.Spacing.xl)
        }.padding(.bottom, Design.Spacing.sm)
    }
    private var folderDisplay: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var p = conversation.folderPath
        if p.hasPrefix(home) { p = "~" + p.dropFirst(home.count) }
        return p
    }
}

// MARK: - Bubble

struct BubbleView: View {
    let message: Message
    var body: some View {
        HStack(alignment: .top, spacing: Design.Spacing.md) {
            if message.role == .assistant { AvatarView(role: .assistant) } else { Spacer(minLength: 60) }
            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                if message.role == .assistant {
                    MarkdownRenderer(text: message.content)
                        .padding(.horizontal, Design.Spacing.lg).padding(.vertical, Design.Spacing.md)
                        .background(Design.Color.assistantBg).clipShape(RoundedRectangle(cornerRadius: Design.Radius.lg))
                        .contextMenu { Button("复制") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(message.content, forType: .string) } }
                } else {
                    Text(message.content).font(Design.Font.body).bubbleStyle(isUser: true)
                }
                Text(timeStr).font(Design.Font.caption).foregroundColor(.secondary.opacity(0.6))
            }
            if message.role == .user { AvatarView(role: .user) } else { Spacer(minLength: 60) }
        }
    }
    private var timeStr: String { let f = DateFormatter(); f.dateFormat = "HH:mm"; return f.string(from: message.timestamp) }
}

struct AvatarView: View {
    let role: Message.Role
    var body: some View {
        ZStack {
            Circle().fill(role == .assistant ? Design.Color.accentBgStrong : Design.Color.accent.opacity(0.2)).frame(width: 32, height: 32)
            Image(systemName: role == .assistant ? "sparkles" : "person.fill").font(.system(size: 13))
                .foregroundColor(role == .assistant ? Design.Color.accent : Design.Color.accent.opacity(0.7))
        }
    }
}

struct StreamingView: View {
    let text: String; let status: String
    var body: some View {
        HStack(alignment: .top, spacing: Design.Spacing.md) {
            AvatarView(role: .assistant)
            VStack(alignment: .leading, spacing: 8) {
                MarkdownRenderer(text: text)
                    .padding(.horizontal, Design.Spacing.lg).padding(.vertical, Design.Spacing.md)
                    .background(Design.Color.assistantBg).clipShape(RoundedRectangle(cornerRadius: Design.Radius.lg))
                StatusLine(text: status)
            }
            Spacer(minLength: 60)
        }
    }
}

struct StatusBubble: View {
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: Design.Spacing.md) {
            AvatarView(role: .assistant)
            StatusLine(text: text)
            Spacer(minLength: 60)
        }
    }
}

struct ThinkingBubble: View {
    @State private var step = 0
    var body: some View {
        HStack(alignment: .top, spacing: Design.Spacing.md) {
            AvatarView(role: .assistant)
            HStack(spacing: 4) {
                HStack(spacing: 3) { ForEach(0..<3) { i in Circle().fill(Design.Color.accent.opacity(step == i ? 0.8 : 0.2)).frame(width: 5, height: 5).scaleEffect(step == i ? 1.2 : 1) } }
                Text("Claude 正在思考...").font(Design.Font.caption).foregroundColor(.secondary)
            }
            .padding(.horizontal, Design.Spacing.lg).padding(.vertical, Design.Spacing.md)
            .background(Design.Color.assistantBg).clipShape(RoundedRectangle(cornerRadius: Design.Radius.lg))
            Spacer(minLength: 60)
        }
        .onAppear { Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in withAnimation { step = (step + 1) % 3 } } }
    }
}

struct StatusLine: View {
    let text: String
    @State private var step = 0
    var body: some View {
        HStack(spacing: 4) {
            HStack(spacing: 3) { ForEach(0..<3) { i in Circle().fill(Design.Color.accent.opacity(step == i ? 0.7 : 0.15)).frame(width: 4, height: 4).scaleEffect(step == i ? 1.1 : 1) } }
            Text(text).font(Design.Font.caption).foregroundColor(.secondary)
        }
        .padding(.leading, 4)
        .onAppear { Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { _ in withAnimation { step = (step + 1) % 3 } } }
    }
}

// MARK: - Input Bar

struct InputBar: View {
    @Binding var text: String; let isRunning: Bool; @Binding var permissionMode: String
    let onSend: () -> Void; let onCancel: () -> Void
    @State private var showPerms = false
    @State private var isComposing = false
    @FocusState private var fieldFocus: Bool
    private var canSend: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        HStack(alignment: .center, spacing: Design.Spacing.sm) {
            Button { showPerms.toggle() } label: {
                HStack(spacing: 4) {
                    Image(systemName: permIcon).font(.system(size: 11))
                    Text(permLabel).font(Design.Font.caption)
                }.foregroundColor(permColor).padding(.horizontal, 8).padding(.vertical, 4)
                    .background(permColor.opacity(0.08)).clipShape(RoundedRectangle(cornerRadius: Design.Radius.sm))
            }.buttonStyle(.plain).popover(isPresented: $showPerms, arrowEdge: .bottom) {
                PermPopover(selected: $permissionMode, dismiss: { showPerms = false })
            }
            ZStack {
                if text.isEmpty && !isComposing {
                    Text("输入消息，Enter 发送，Shift+Enter 换行").font(Design.Font.body)
                        .foregroundColor(.secondary.opacity(0.4)).padding(.leading, 4)
                        .allowsHitTesting(false)
                }
                CenteredTextEditor(text: $text, font: NSFont.systemFont(ofSize: 13.5), maxHeight: 120, minHeight: 36)
                    .focused($fieldFocus)
                    .frame(minHeight: 36, maxHeight: 120).fixedSize(horizontal: false, vertical: true)
                    .background(NSEventMonitor { event in
                        guard event.keyCode == 36, event.window?.isKeyWindow == true, fieldFocus, canSend, !isRunning
                        else { return event }
                        if event.modifierFlags.contains(.shift) { return event }
    if NSApp.keyWindow?.firstResponder?.responds(to: #selector(NSTextInputClient.hasMarkedText)) == true,
       let hasMarked = NSApp.keyWindow?.firstResponder?.value(forKey: "hasMarkedText") as? Bool,
       hasMarked {
        return event
    }
                        DispatchQueue.main.async { onSend() }
                        return nil
                    })
            }
            .padding(.horizontal, 10).padding(.vertical, 0)
            .background(RoundedRectangle(cornerRadius: Design.Radius.md).fill(Color.primary.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: Design.Radius.md).strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)))
            if isRunning {
                Button(action: onCancel) { Image(systemName: "stop.circle.fill").font(.system(size: 24)).foregroundColor(.red.opacity(0.8)) }.buttonStyle(.plain).help("停止")
            } else {
                Button(action: onSend) { Image(systemName: "arrow.up.circle.fill").font(.system(size: 24)).foregroundColor(canSend ? Design.Color.accent : .secondary.opacity(0.3)) }.buttonStyle(.plain).disabled(!canSend).help("发送")
            }
        }
        .padding(.horizontal, Design.Spacing.lg).padding(.vertical, Design.Spacing.md)
        .background(Design.Color.sidebarBg)
        .onReceive(Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()) { _ in
            let fr = NSApp.keyWindow?.firstResponder
            let composing = fr?.responds(to: #selector(NSTextInputClient.hasMarkedText)) == true &&
                (fr?.value(forKey: "hasMarkedText") as? Bool) == true
            if isComposing != composing { isComposing = composing }
        }
    }

    private var permIcon: String { permissionMode == "acceptEdits" ? "checkmark.shield" : permissionMode == "auto" ? "bolt.shield" : permissionMode == "plan" ? "text.magnifyingglass" : "shield" }
    private var permLabel: String { permissionMode == "acceptEdits" ? "编辑" : permissionMode == "auto" ? "自动" : permissionMode == "plan" ? "计划" : "默认" }
    private var permColor: SwiftUI.Color { permissionMode == "acceptEdits" ? .blue : permissionMode == "auto" ? .green : permissionMode == "plan" ? .purple : .secondary }
}

struct NSEventMonitor: NSViewRepresentable {
    let handler: (NSEvent) -> NSEvent?
    func makeNSView(context: Context) -> NSView { let v = NSView(); context.coordinator.monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { handler($0) ?? $0 }; return v }
    func updateNSView(_ nsView: NSView, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator() }
    class Coordinator { var monitor: Any?; deinit { if let m = monitor { NSEvent.removeMonitor(m) } } }
}

struct PermPopover: View {
    @Binding var selected: String; let dismiss: () -> Void
    private let modes: [(String, String, String)] = [("default","默认","按需请求权限"),("acceptEdits","接受编辑","自动接受文件编辑"),("plan","计划模式","先展示计划再执行"),("auto","自动批准","自动批准所有操作")]
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("权限模式").font(Design.Font.captionBold).foregroundColor(.secondary).padding(.horizontal, Design.Spacing.md).padding(.bottom, 4)
            ForEach(modes, id: \.0) { (id, name, desc) in
                Button { selected = id; dismiss() } label: {
                    HStack {
                        Image(systemName: selected == id ? "checkmark.circle.fill" : "circle").font(.system(size: 13)).foregroundColor(selected == id ? Design.Color.accent : .secondary.opacity(0.4))
                        VStack(alignment: .leading, spacing: 1) { Text(name).font(Design.Font.body); Text(desc).font(Design.Font.caption).foregroundColor(.secondary) }
                        Spacer()
                    }.padding(.horizontal, Design.Spacing.md).padding(.vertical, Design.Spacing.sm).contentShape(Rectangle())
                }.buttonStyle(.plain)
            }
        }.padding(.vertical, Design.Spacing.sm).frame(width: 220)
    }
}

// MARK: - Welcome

struct WelcomeView: View {
    @State private var appear = false
    let claudeMissing: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: Design.Spacing.xl) {
                ZStack {
                    Circle().fill(claudeMissing ? Color.orange.opacity(0.1) : Design.Color.accentBg).frame(width: 80, height: 80)
                    Image(systemName: claudeMissing ? "exclamationmark.triangle" : "sparkles")
                        .font(.system(size: 32, weight: .light))
                        .foregroundColor(claudeMissing ? .orange : Design.Color.accent)
                }
                .scaleEffect(appear ? 1 : 0.8).opacity(appear ? 1 : 0)
                VStack(spacing: 6) {
                    Text("见一面").font(.system(size: 28, weight: .medium))
                    Text(claudeMissing ? "需要安装 Claude Code CLI" : "Claude Code 的优雅界面")
                        .font(Design.Font.body).foregroundColor(claudeMissing ? .orange : .secondary)
                }
                .opacity(appear ? 1 : 0).offset(y: appear ? 0 : 8)

                if claudeMissing {
                    MissingGuide()
                        .opacity(appear ? 1 : 0).offset(y: appear ? 0 : 12)
                } else {
                    VStack(spacing: 10) {
                        Hint(icon: "folder.badge.plus", text: "点击左侧  +  创建新对话，选择一个工作目录")
                        Hint(icon: "message", text: "在输入框中输入消息，Enter 发送")
                        Hint(icon: "doc.on.doc", text: "拖拽文件或文件夹到对话区，自动复制到项目目录")
                    }
                    .opacity(appear ? 1 : 0).offset(y: appear ? 0 : 12)
                }
            }
            Spacer()
            Text("版本 1.0").font(Design.Font.caption).foregroundColor(.secondary.opacity(0.4)).padding(.bottom, Design.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity).background(Design.Color.chatBg)
        .onAppear { withAnimation(.easeOut(duration: 0.6)) { appear = true } }
    }
}
struct Hint: View {
    let icon: String; let text: String
    var body: some View { HStack(spacing: Design.Spacing.sm) { Image(systemName: icon).font(.system(size: 12)).foregroundColor(Design.Color.accent.opacity(0.6)).frame(width: 20); Text(text).font(Design.Font.caption).foregroundColor(.secondary) } }
}

// MARK: - Missing Claude Guide

struct MissingGuide: View {
    @State private var copyDone = false

    var body: some View {
        VStack(alignment: .leading, spacing: Design.Spacing.sm) {
            Text("安装步骤").font(Design.Font.captionBold).foregroundColor(.orange)
            VStack(alignment: .leading, spacing: 8) {
                StepView(num: "1", title: "安装 Node.js", cmd: "curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash")
                StepView(num: "2", title: "安装 Claude Code", cmd: "npm install -g @anthropic-ai/claude-code")
                StepView(num: "3", title: "验证安装后重启本应用", cmd: "claude --version")
            }
        }
        .padding(Design.Spacing.lg)
        .background(RoundedRectangle(cornerRadius: Design.Radius.md).fill(Color.orange.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: Design.Radius.md).strokeBorder(Color.orange.opacity(0.2), lineWidth: 1))
        .frame(maxWidth: 420)
    }
}

struct StepView: View {
    let num: String; let title: String; let cmd: String
    @State private var copied = false

    var body: some View {
        HStack(alignment: .top, spacing: Design.Spacing.sm) {
            Text(num).font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color.orange.opacity(0.7)))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 12, weight: .medium))
                HStack(spacing: Design.Spacing.sm) {
                    Text(cmd).font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(cmd, forType: .string)
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                    }) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10))
                            .foregroundColor(copied ? .green : .secondary.opacity(0.6))
                    }.buttonStyle(.plain)
                }
            }
        }
    }
}

struct MissingBanner: View {
    var body: some View {
        HStack(spacing: Design.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 11)).foregroundColor(.orange)
            Text("未检测到 Claude Code，部分功能不可用").font(Design.Font.caption).foregroundColor(.orange)
            Spacer()
        }
        .padding(.horizontal, Design.Spacing.md).padding(.vertical, Design.Spacing.xs)
        .background(Color.orange.opacity(0.08))
    }
}
