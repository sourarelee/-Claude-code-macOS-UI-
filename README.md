# 见一面

**Claude Code 的优雅 macOS 桌面界面**

> 让 AI 编码更舒适 —— 一个基于 SwiftUI 的原生 macOS 应用，为 [Claude Code](https://docs.anthropic.com/en/docs/claude-code) 提供美观的图形化交互体验。

---

## 界面展示
<img width="1470" height="956" alt="image" src="https://github.com/user-attachments/assets/58c2d562-cf16-4812-aebe-cb7f3b548134" />

## 功能特性

- **多对话管理**：侧边栏支持创建、切换、重命名和删除对话，每个对话绑定独立的工作目录
- **流式输出**：AI 回复实时流式渲染，支持 Markdown（标题、代码块、列表、引用、链接、行内代码等）
- **文件上下文**：每个对话可选择本地文件夹作为工作目录，AI 可直接阅读和编辑该目录下的文件
- **拖拽导入**：支持将文件或文件夹拖入对话窗口，自动复制到项目目录
- **权限模式**：四种权限模式可切换 —— 默认（按需请求）、接受编辑、计划模式、自动批准
- **主题切换**：支持浅色 / 深色 / 跟随系统三种外观模式
- **会话持久化**：所有对话和消息自动保存在 `~/.claude/conversations/` 下，关闭应用不会丢失
- **原生体验**：macOS 原生窗口风格，隐藏标题栏，支持侧边栏快捷键，最小窗口尺寸 900×520

## 系统要求

- **macOS 14.0 (Sonoma)** 或更高版本
- **Claude Code** 已安装并可在终端中使用（需在 `~/.local/bin/claude`、`/opt/homebrew/bin/claude`、`/usr/local/bin/claude`、`/usr/bin/claude` 或 `~/.nvm/` 路径下可找到）
- Xcode 15.0+（如需从源码构建）

## 快速开始

### 直接使用

1. 打开 `见一面.dmg`，将 `见一面.app` 拖入 `应用程序` 文件夹
2. 首次打开时，macOS 可能会提示安全警告，请在 **系统设置 → 隐私与安全性** 中允许运行
3. 点击左侧 **+** 按钮，选择一个工作目录（项目文件夹），创建新对话
4. 在输入框中输入消息，按 **Enter** 发送，**Shift+Enter** 换行
5. 等待 AI 回复，支持实时流式渲染

### 从源码构建

```bash
# 1. 生成 Xcode 项目文件
ruby gen_xcode.rb > ClaudeChat.xcodeproj/project.pbxproj

# 2. 打开项目并构建
xcodebuild -project ClaudeChat.xcodeproj \
  -scheme 见一面 \
  -configuration Release \
  -derivedDataPath ./build

# 或直接在 Xcode 中打开 ClaudeChat.xcodeproj 并运行
```

## 项目结构

```
.
├── Sources/ClaudeChat/              # 主源码目录
│   ├── ClaudeChatApp.swift          # 应用入口 (SwiftUI @main)
│   ├── DesignSystem.swift           # 设计系统常量（颜色/间距/字体/圆角）
│   ├── Info.plist                   # 应用配置清单
│   ├── Models/
│   │   ├── Message.swift            # 消息模型（用户/助手/时间戳）
│   │   ├── Conversation.swift       # 对话模型（会话ID/文件夹/消息列表）
│   │   └── AppSettings.swift        # 应用设置（主题模式）
│   ├── Services/
│   │   ├── ClaudeService.swift      # Claude 进程管理（启动/流式解析/停止）
│   │   └── ConversationStore.swift  # 对话持久化存储（~/.claude/conversations/）
│   ├── ViewModels/
│   │   ├── ChatViewModel.swift      # 聊天视图模型（发送/接收/状态管理）
│   │   └── SidebarViewModel.swift   # 侧边栏视图模型（对话列表/创建/删除）
│   └── Views/
│       ├── ContentView.swift        # 主界面（导航分割、气泡、输入栏、欢迎页）
│       ├── SidebarView.swift        # 侧边栏（对话列表/右键菜单）
│       ├── SettingsView.swift       # 设置面板（主题切换/关于）
│       ├── MarkdownRenderer.swift   # Markdown 渲染器（支持代码块/列表/引用等）
│       ├── CenteredTextEditor.swift # 居中文本输入框（NSTextView 封装）
│       └── FileDropModifier.swift   # 拖拽文件处理（拖入自动复制到项目目录）
├── ClaudeChat.xcodeproj/            # Xcode 项目文件
├── gen_xcode.rb                     # Ruby 脚本：生成 .pbxproj 文件
├── AppIcon.icns                     # 应用图标
├── 见一面.app                       # 已编译的应用包
└── 见一面.dmg                       # DMG 安装包
```

## 架构说明

```
┌─────────────────────────────────────────────────┐
│                  SwiftUI View Layer             │
│  ContentView / SidebarView / SettingsView / ... │
├─────────────────────────────────────────────────┤
│                ViewModel Layer                  │
│       ChatViewModel (发送/流式/状态)              │
│       SidebarViewModel (列表/操作)               │
├─────────────────────────────────────────────────┤
│                 Service Layer                   │
│  ClaudeService ─── 启动 claude CLI 进程           │
│  ConversationStore ─── 磁盘持久化读写              │
├─────────────────────────────────────────────────┤
│                  Model Layer                    │
│      Message / Conversation / AppSettings       │
└─────────────────────────────────────────────────┘
           │                    ▲
           │  Process (stdout)  │  Process (stdin)
           ▼                    │
         ┌──────────────────────────┐
         │   claude CLI (本地进程)    │
         │   --output-format        │
         │   stream-json            │
         └──────────────────────────┘
```

- 应用通过 `Process` (NSTask) 启动本地 `claude` 命令行工具
- 使用 `--output-format stream-json` 获取结构化流式输出
- 实时解析 JSON 流中的 `stream_event`（文本增量）和 `system`（状态消息）
- 对话数据存储在 `~/.claude/conversations/{uuid}/messages.json` 中

## 技术栈

| 技术 | 说明 |
|------|------|
| SwiftUI | macOS 原生 UI 框架 |
| AppKit | 部分底层控件（NSTextView、NSOpenPanel） |
| Combine | 数据绑定与状态管理（`@Published`、`@StateObject`） |
| Foundation | 进程管理、文件操作、JSON 解析 |
| Ruby | 自动生成 Xcode 项目文件 |
| Claude Code CLI | AI 引擎后端 |

## 许可证
沐枫慕夏，倾情巨献
