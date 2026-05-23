import Foundation

enum ClaudeStreamEvent {
    case status(String)
    case text(String)
    case done
}

final class ClaudeService {
    let claudePath: String
    private var process: Process?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    private var buffer = ""
    var isRunning: Bool { process?.isRunning ?? false }

    /// 是否检测到可用的 Claude Code CLI
    static var isAvailable: Bool { foundPath != nil }

    /// 自动搜索到的 claude 可执行文件路径（未找到则 nil）
    static var foundPath: String? {
        let fm = FileManager.default
        let home = fm.homeDirectoryForCurrentUser.path
        var paths: [String] = []
        let nvmDir = "\(home)/.nvm/versions"
        if let runtimes = try? fm.contentsOfDirectory(atPath: nvmDir) {
            for rt in runtimes {
                let vd = "\(nvmDir)/\(rt)"
                if let vers = try? fm.contentsOfDirectory(atPath: vd) {
                    for v in vers.sorted().reversed() { paths.append("\(vd)/\(v)/bin/claude") }
                }
            }
        }
        paths.append(contentsOf: [
            "\(home)/.local/bin/claude",
            "/opt/homebrew/bin/claude",
            "/usr/local/bin/claude",
            "/usr/bin/claude"
        ])
        for p in paths where fm.isExecutableFile(atPath: p) { return p }

        // 最后尝试通过 which 在 PATH 中查找
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["which", "claude"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let result = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !result.isEmpty && fm.isExecutableFile(atPath: result) { return result }
        } catch {}

        return nil
    }

    /// 未安装 Claude Code 时展示的安装指引
    static let installInstructions = """
        未检测到 Claude Code 命令行工具。

        请按以下步骤安装：

        1️⃣  安装 Node.js（推荐 nvm）：
           curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
           重启终端后：nvm install node

        2️⃣  安装 Claude Code：
           npm install -g @anthropic-ai/claude-code

        3️⃣  验证安装：
           claude --version

        安装完成后重启「见一面」即可。
        """

    init() { self.claudePath = ClaudeService.foundPath ?? "claude" }

    func send(
        sessionId: String, message: String, workingDirectory: String?,
        permissionMode: String, resume: Bool,
        onEvent: @escaping (ClaudeStreamEvent) -> Void
    ) {
        stop()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: claudePath)
        if let dir = workingDirectory { process.currentDirectoryURL = URL(fileURLWithPath: dir) }

        // 确保 sessionId 合法
        let sid = normalizeUUID(sessionId)

        var args = ["-p", "--output-format", "stream-json", "--verbose", "--include-partial-messages"]
        if resume {
            args.append("--continue")
        } else {
            args.append(contentsOf: ["--session-id", sid])
        }
        if permissionMode != "default" { args.append(contentsOf: ["--permission-mode", permissionMode]) }
        args.append(message)
        process.arguments = args

        // stdin: GUI 应用没有 stdin，显式给空
        let inPipe = Pipe()
        inPipe.fileHandleForWriting.closeFile()
        process.standardInput = inPipe

        let outPipe = Pipe()
        process.standardOutput = outPipe

        let errPipe = Pipe()
        process.standardError = errPipe
        errPipe.fileHandleForReading.readabilityHandler = { h in
            let d = h.availableData
            if let s = String(data: d, encoding: .utf8), !s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                print("[ClaudeService stderr] \(s.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
        }

        // 不覆盖环境变量，只追加必要项
        if process.environment == nil {
            process.environment = ProcessInfo.processInfo.environment
        }
        process.environment?["NO_COLOR"] = "1"
        process.environment?["CLAUDE_CODE_SIMPLE"] = "1"

        self.process = process
        self.outputPipe = outPipe
        self.errorPipe = errPipe
        self.buffer = ""

        outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let self = self else { return }
            if let chunk = String(data: data, encoding: .utf8) {
                self.buffer += chunk
                self.processBuffer(onEvent: onEvent)
            }
        }

        process.terminationHandler = { [weak self] proc in
            let exitCode = proc.terminationStatus
            if exitCode != 0 {
                print("[ClaudeService] 进程退出, exitCode=\(exitCode)")
            }
            if let self = self {
                if let remaining = try? self.outputPipe?.fileHandleForReading.readToEnd(),
                   let text = String(data: remaining, encoding: .utf8), !text.isEmpty {
                    self.buffer += text
                }
                self.processBuffer(onEvent: onEvent, final: true)
            }
            self?.outputPipe?.fileHandleForReading.readabilityHandler = nil
            self?.errorPipe?.fileHandleForReading.readabilityHandler = nil
            DispatchQueue.main.async { onEvent(.done) }
        }

        do {
            try process.run()
            DispatchQueue.main.async { onEvent(.status("正在连接...")) }
        } catch {
            print("[ClaudeService] 启动失败: \(error)")
            DispatchQueue.main.async { onEvent(.done) }
        }
    }

    private func normalizeUUID(_ s: String) -> String {
        if UUID(uuidString: s) != nil { return s }
        let cleaned = s.replacingOccurrences(of: "-", with: "")
        if cleaned.count == 32 {
            var fmt = ""
            for (i, c) in cleaned.enumerated() {
                if [8, 12, 16, 20].contains(i) { fmt += "-" }
                fmt.append(c)
            }
            if UUID(uuidString: fmt) != nil { return fmt }
        }
        let newId = UUID().uuidString
        print("[ClaudeService] sessionId '\(s.prefix(16))...' 无效，生成: \(newId)")
        return newId
    }

    // MARK: - Buffer

    private func processBuffer(onEvent: @escaping (ClaudeStreamEvent) -> Void, final: Bool = false) {
        var lines = buffer.components(separatedBy: "\n")
        let endsWithNewline = buffer.hasSuffix("\n")

        if final {
            buffer = ""
        } else if lines.count <= 1 && !endsWithNewline {
            if let d = lines[0].trimmingCharacters(in: .whitespaces).data(using: .utf8),
               (try? JSONSerialization.jsonObject(with: d)) != nil {
                buffer = ""
            } else {
                return
            }
        } else {
            buffer = endsWithNewline ? "" : (lines.last ?? "")
            if !endsWithNewline { lines.removeLast() }
        }

        for line in lines where !line.trimmingCharacters(in: .whitespaces).isEmpty {
            parseLine(line, onEvent: onEvent)
        }
    }

    private func parseLine(_ line: String, onEvent: @escaping (ClaudeStreamEvent) -> Void) {
        guard let data = line.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return }

        switch json["type"] as? String ?? "" {
        case "system":
            if json["subtype"] as? String == "init" {
                let model = json["model"] as? String ?? "Claude"
                DispatchQueue.main.async { onEvent(.status("模型: \(model)")) }
            }
        case "stream_event":
            guard let event = json["event"] as? [String: Any] else { return }
            switch event["type"] as? String ?? "" {
            case "content_block_start":
                if let block = event["content_block"] as? [String: Any],
                   block["type"] as? String == "tool_use" {
                    let name = block["name"] as? String ?? ""
                    DispatchQueue.main.async { onEvent(.status(self.toolLabel(name))) }
                }
            case "content_block_delta":
                if let delta = event["delta"] as? [String: Any],
                   delta["type"] as? String == "text_delta",
                   let text = delta["text"] as? String {
                    DispatchQueue.main.async { onEvent(.text(text)) }
                }
            default: break
            }
        case "user":
            if let msg = json["message"] as? [String: Any],
               let content = msg["content"] as? [[String: Any]],
               content.contains(where: { ($0["type"] as? String) == "tool_result" }) {
                DispatchQueue.main.async {
                    onEvent(.text("\n\n"))
                    onEvent(.status("执行完成"))
                }
            }
        default: break
        }
    }

    private func toolLabel(_ name: String) -> String {
        switch name {
        case "Read": return "读取文件中..."
        case "Write", "Edit": return "编辑文件中..."
        case "Bash": return "执行命令中..."
        case "Grep": return "搜索代码中..."
        case "Glob": return "查找文件中..."
        case "WebSearch": return "搜索网页中..."
        case "WebFetch": return "获取网页内容..."
        case "Task": return "执行子任务中..."
        case "TodoWrite": return "更新任务列表中..."
        default: return "调用 \(name)..."
        }
    }

    func stop() {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        errorPipe?.fileHandleForReading.readabilityHandler = nil
        if process?.isRunning == true {
            process?.terminate()
            process?.waitUntilExit()
        }
        process = nil
        outputPipe = nil
        errorPipe = nil
    }
}
