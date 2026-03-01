import Foundation

@MainActor
class RestoreManager: ObservableObject, OperationManager {
    @Published var progress: Double = 0
    @Published var logs: [String] = []
    @Published var isComplete: Bool = false
    @Published var hasFailed: Bool = false

    private let home = FileManager.default.homeDirectoryForCurrentUser.path

    func start(from url: URL) {
        logs = []
        isComplete = false
        hasFailed = false
        progress = 0
        Task { await performRestore(from: url) }
    }

    private func log(_ msg: String) {
        logs.append(msg)
    }

    private func setProgress(_ v: Double) {
        progress = v
    }

    private func performRestore(from url: URL) async {
        log("🦞 SaferClaw Restore starting...")
        log("📦 File: \(url.lastPathComponent)")
        setProgress(0.05)

        // Extract archive
        log("📂 Extracting backup...")
        let tmpDir = NSTemporaryDirectory() + "saferclaw-\(Int(Date().timeIntervalSince1970))"
        try? FileManager.default.createDirectory(atPath: tmpDir, withIntermediateDirectories: true)
        let extract = await shell("tar -xzf '\(url.path)' -C '\(tmpDir)' 2>&1")
        if extract.code != 0 {
            log("❌ Extract failed: \(extract.out)")
            hasFailed = true
            return
        }
        log("✅ Extracted successfully")
        setProgress(0.25)

        // Find backup root
        var backupRoot = tmpDir
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: tmpDir),
           contents.count == 1 {
            backupRoot = tmpDir + "/" + contents[0]
        }

        // Restore files
        log("🔄 Restoring files...")
        let items: [(String, String)] = [
            (".openclaw", "\(home)/.openclaw"),
            ("Projects", "\(home)/Projects"),
            (".zshrc", "\(home)/.zshrc"),
            (".zprofile", "\(home)/.zprofile"),
            (".bash_profile", "\(home)/.bash_profile"),
        ]

        for (i, (rel, dst)) in items.enumerated() {
            let src = backupRoot + "/" + rel
            guard FileManager.default.fileExists(atPath: src) else {
                log("⏭ Skipping \(rel) (not in backup)")
                continue
            }
            if FileManager.default.fileExists(atPath: dst) {
                try? FileManager.default.removeItem(atPath: dst)
            }
            let parent = (dst as NSString).deletingLastPathComponent
            try? FileManager.default.createDirectory(atPath: parent, withIntermediateDirectories: true)
            do {
                try FileManager.default.copyItem(atPath: src, toPath: dst)
                log("✅ Restored \(rel)")
            } catch {
                log("⚠️ Could not restore \(rel): \(error.localizedDescription)")
            }
            setProgress(0.25 + Double(i) / Double(items.count) * 0.3)
        }

        // LaunchAgents
        let laSrc = backupRoot + "/LaunchAgents"
        if FileManager.default.fileExists(atPath: laSrc),
           let agents = try? FileManager.default.contentsOfDirectory(atPath: laSrc) {
            let laDst = "\(home)/Library/LaunchAgents"
            try? FileManager.default.createDirectory(atPath: laDst, withIntermediateDirectories: true)
            for a in agents {
                try? FileManager.default.copyItem(atPath: "\(laSrc)/\(a)", toPath: "\(laDst)/\(a)")
                log("✅ Restored LaunchAgent: \(a)")
            }
        }
        setProgress(0.6)

        // Homebrew
        log("🔍 Checking Homebrew...")
        let brewCheck = await shell("which brew 2>/dev/null || ls /opt/homebrew/bin/brew 2>/dev/null")
        if brewCheck.code != 0 {
            log("⬇️ Installing Homebrew (macOS will ask for your password)...")
            let installCmd = #"NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)""#
            let r = await runPrivileged(installCmd)
            log(r.code == 0 ? "✅ Homebrew installed" : "⚠️ Homebrew: \(r.out.prefix(150))")
        } else {
            log("✅ Homebrew ready")
        }
        setProgress(0.72)

        // Node.js
        log("🔍 Checking Node.js...")
        let nodeCheck = await shell("/opt/homebrew/bin/node --version 2>/dev/null || node --version 2>/dev/null")
        if nodeCheck.code != 0 {
            log("⬇️ Installing Node.js (macOS will ask for your password)...")
            let r = await runPrivileged("/opt/homebrew/bin/brew install node 2>&1 || /usr/local/bin/brew install node 2>&1")
            log(r.code == 0 ? "✅ Node.js installed" : "⚠️ Node: \(r.out.prefix(150))")
        } else {
            log("✅ Node.js \(nodeCheck.out.trimmingCharacters(in: .whitespacesAndNewlines)) ready")
        }
        setProgress(0.85)

        // OpenClaw
        log("🔍 Checking OpenClaw...")
        let clawCheck = await shell("which openclaw 2>/dev/null || ls ~/.npm-global/bin/openclaw 2>/dev/null || ls /opt/homebrew/bin/openclaw 2>/dev/null")
        if clawCheck.code != 0 {
            log("⬇️ Installing OpenClaw (macOS will ask for your password)...")
            let npmSetup = "mkdir -p ~/.npm-global && /opt/homebrew/bin/npm config set prefix '~/.npm-global' 2>/dev/null; /opt/homebrew/bin/npm install -g openclaw 2>&1 || npm install -g openclaw 2>&1"
            let r1 = await shell(npmSetup)
            if r1.code == 0 {
                log("✅ OpenClaw installed")
            } else {
                let r2 = await runPrivileged("/opt/homebrew/bin/npm install -g openclaw 2>&1 || npm install -g openclaw 2>&1")
                log(r2.code == 0 ? "✅ OpenClaw installed" : "⚠️ OpenClaw: \(r2.out.prefix(150))")
            }
        } else {
            log("✅ OpenClaw ready")
        }
        setProgress(0.95)

        // Start gateway
        log("🚀 Starting OpenClaw gateway...")
        let _ = await shell("(~/.npm-global/bin/openclaw gateway start 2>&1 || openclaw gateway start 2>&1) & disown")
        log("⚡ Gateway launching in background...")

        // Cleanup
        try? FileManager.default.removeItem(atPath: tmpDir)

        setProgress(1.0)
        log("")
        log("🎉 Restore complete! Jarvis is ready.")
        isComplete = true
    }

    /// Run a shell command with macOS admin privileges via osascript.
    /// macOS automatically shows its native password dialog.
    private func runPrivileged(_ command: String) async -> (code: Int32, out: String) {
        let escaped = command
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let scriptContent = "do shell script \"\(escaped)\" with administrator privileges"
        let tmpScript = NSTemporaryDirectory() + "saferclaw-priv-\(Int(Date().timeIntervalSince1970)).scpt"
        try? scriptContent.write(toFile: tmpScript, atomically: true, encoding: .utf8)
        let result = await shell("osascript '\(tmpScript)' 2>&1")
        try? FileManager.default.removeItem(atPath: tmpScript)
        return result
    }

    private func shell(_ cmd: String) async -> (code: Int32, out: String) {
        await withCheckedContinuation { cont in
            let task = Process()
            task.launchPath = "/bin/bash"
            task.arguments = ["-lc", cmd]
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe
            task.terminationHandler = { p in
                let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                cont.resume(returning: (p.terminationStatus, out))
            }
            try? task.run()
        }
    }
}
