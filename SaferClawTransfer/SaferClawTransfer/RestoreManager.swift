import Foundation

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
        
        Task {
            await performRestore(from: url)
        }
    }
    
    @MainActor
    private func log(_ msg: String) {
        logs.append(msg)
    }
    
    @MainActor
    private func setProgress(_ v: Double) {
        progress = v
    }
    
    private func performRestore(from url: URL) async {
        let backupPath = url.path
        await log("⚡ Starting SaferClaw Transfer restore...")
        await log("📦 Backup file: \(url.lastPathComponent)")
        await setProgress(0.05)
        
        // Step 1: Check/install Homebrew
        await log("")
        await log("🔍 Checking Homebrew...")
        let brewCheck = await runShell("which brew")
        if brewCheck.exitCode != 0 {
            await log("⬇️ Installing Homebrew (this may take a few minutes)...")
            let brewInstall = await runShell(#"/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)""#)
            if brewInstall.exitCode == 0 {
                await log("✅ Homebrew installed")
            } else {
                await log("⚠️ Homebrew install failed — continuing anyway")
            }
        } else {
            await log("✅ Homebrew already installed")
        }
        await setProgress(0.2)
        
        // Step 2: Check/install Node.js
        await log("")
        await log("🔍 Checking Node.js...")
        let nodeCheck = await runShell("which node")
        if nodeCheck.exitCode != 0 {
            await log("⬇️ Installing Node.js via Homebrew...")
            let nodeInstall = await runShell("brew install node")
            if nodeInstall.exitCode == 0 {
                await log("✅ Node.js installed")
            } else {
                await log("⚠️ Node.js install failed — continuing anyway")
            }
        } else {
            await log("✅ Node.js already installed")
        }
        await setProgress(0.35)
        
        // Step 3: Extract backup
        await log("")
        await log("📂 Extracting backup archive...")
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("saferclaw-restore-\(Int(Date().timeIntervalSince1970))").path
        try? FileManager.default.createDirectory(atPath: tmpDir, withIntermediateDirectories: true)
        
        let extractResult = await runShell("tar -xzf '\(backupPath)' -C '\(tmpDir)'")
        if extractResult.exitCode != 0 {
            await log("❌ Failed to extract archive: \(extractResult.stderr)")
            hasFailed = true
            return
        }
        await log("✅ Archive extracted")
        await setProgress(0.5)
        
        // Step 4: Restore each item
        await log("")
        await log("🔄 Restoring files...")
        
        let restorations: [(String, String)] = [
            ("\(tmpDir)/.openclaw", "\(home)/.openclaw"),
            ("\(tmpDir)/Projects", "\(home)/Projects"),
            ("\(tmpDir)/.npm-global/lib/node_modules/openclaw", "\(home)/.npm-global/lib/node_modules/openclaw"),
            ("\(tmpDir)/.zshrc", "\(home)/.zshrc"),
            ("\(tmpDir)/.zprofile", "\(home)/.zprofile"),
            ("\(tmpDir)/.bash_profile", "\(home)/.bash_profile"),
        ]
        
        for (i, (src, dst)) in restorations.enumerated() {
            let fraction = Double(i) / Double(restorations.count)
            await setProgress(0.5 + fraction * 0.3)
            
            guard FileManager.default.fileExists(atPath: src) else {
                await log("⏭ Skipping \((src as NSString).lastPathComponent) (not in backup)")
                continue
            }
            
            let dstParent = (dst as NSString).deletingLastPathComponent
            try? FileManager.default.createDirectory(atPath: dstParent, withIntermediateDirectories: true)
            
            // Backup existing if present
            if FileManager.default.fileExists(atPath: dst) {
                let backupDst = dst + ".pre-restore"
                try? FileManager.default.removeItem(atPath: backupDst)
                try? FileManager.default.moveItem(atPath: dst, toPath: backupDst)
            }
            
            do {
                try FileManager.default.copyItem(atPath: src, toPath: dst)
                await log("✅ Restored \((dst as NSString).lastPathComponent)")
            } catch {
                await log("⚠️ Failed to restore \((dst as NSString).lastPathComponent): \(error.localizedDescription)")
            }
        }
        
        // Restore LaunchAgents
        let launchAgentsSrc = "\(tmpDir)/LaunchAgents"
        if FileManager.default.fileExists(atPath: launchAgentsSrc) {
            let dst = "\(home)/Library/LaunchAgents"
            try? FileManager.default.createDirectory(atPath: dst, withIntermediateDirectories: true)
            if let agents = try? FileManager.default.contentsOfDirectory(atPath: launchAgentsSrc) {
                for agent in agents {
                    try? FileManager.default.copyItem(atPath: "\(launchAgentsSrc)/\(agent)", toPath: "\(dst)/\(agent)")
                    await log("✅ Restored LaunchAgent: \(agent)")
                }
            }
        }
        
        await setProgress(0.82)
        
        // Step 5: Check/install OpenClaw
        await log("")
        await log("🔍 Checking OpenClaw...")
        let clawCheck = await runShell("which openclaw || npm list -g openclaw 2>/dev/null | grep openclaw")
        if clawCheck.exitCode != 0 || clawCheck.stdout.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            await log("⬇️ Installing OpenClaw globally...")
            let clawInstall = await runShell("npm install -g openclaw")
            if clawInstall.exitCode == 0 {
                await log("✅ OpenClaw installed")
            } else {
                await log("⚠️ OpenClaw install failed — you may need to run: npm install -g openclaw")
            }
        } else {
            await log("✅ OpenClaw already installed")
        }
        await setProgress(0.92)
        
        // Step 6: Start gateway
        await log("")
        await log("🚀 Starting OpenClaw gateway...")
        let gatewayResult = await runShell("openclaw gateway start 2>&1 || true")
        await log("✅ Gateway started (or already running)")
        
        // Cleanup
        try? FileManager.default.removeItem(atPath: tmpDir)
        
        await setProgress(1.0)
        await log("")
        await log("✅ Restore complete!")
        await log("")
        await log("⚡ Next steps:")
        await log("   • Open a new Terminal window")
        await log("   • Your OpenClaw config has been restored")
        await log("   • Run: openclaw gateway status")
        isComplete = true
    }
    
    private func runShell(_ command: String) async -> (exitCode: Int32, stdout: String, stderr: String) {
        await withCheckedContinuation { cont in
            let task = Process()
            task.launchPath = "/bin/bash"
            task.arguments = ["-l", "-c", command]
            
            let outPipe = Pipe()
            let errPipe = Pipe()
            task.standardOutput = outPipe
            task.standardError = errPipe
            
            task.terminationHandler = { p in
                let out = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                cont.resume(returning: (p.terminationStatus, out, err))
            }
            
            do {
                try task.run()
            } catch {
                cont.resume(returning: (-1, "", error.localizedDescription))
            }
        }
    }
}
