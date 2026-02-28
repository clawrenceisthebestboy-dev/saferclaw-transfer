import Foundation
import Combine

class BackupManager: ObservableObject, OperationManager {
    @Published var progress: Double = 0
    @Published var logs: [String] = []
    @Published var isComplete: Bool = false
    @Published var hasFailed: Bool = false
    
    private let home = FileManager.default.homeDirectoryForCurrentUser.path
    
    func start() {
        logs = []
        isComplete = false
        hasFailed = false
        progress = 0
        
        Task {
            await performBackup()
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
    
    private func performBackup() async {
        await log("⚡ Starting SaferClaw Transfer backup...")
        await setProgress(0.05)
        
        let dateStr = {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd-HHmm"
            return df.string(from: Date())
        }()
        let outputFile = "\(home)/Desktop/SaferClaw-backup-\(dateStr).tar.gz"
        
        // Build list of paths to include
        let pathsToBackup: [(String, String)] = [
            ("\(home)/.openclaw", ".openclaw"),
            ("\(home)/Projects", "Projects"),
            ("\(home)/.npm-global/lib/node_modules/openclaw", ".npm-global/lib/node_modules/openclaw"),
            ("\(home)/.zshrc", ".zshrc"),
            ("\(home)/.zprofile", ".zprofile"),
            ("\(home)/.bash_profile", ".bash_profile"),
        ]
        
        // Create temp staging dir
        let tmpDir = FileManager.default.temporaryDirectory.appendingPathComponent("saferclaw-backup-\(dateStr)").path
        await log("📁 Staging to temp dir...")
        try? FileManager.default.createDirectory(atPath: tmpDir, withIntermediateDirectories: true)
        
        var copiedPaths: [String] = []
        
        for (i, (srcPath, relPath)) in pathsToBackup.enumerated() {
            let fraction = Double(i) / Double(pathsToBackup.count)
            await setProgress(0.05 + fraction * 0.5)
            
            guard FileManager.default.fileExists(atPath: srcPath) else {
                await log("⏭ Skipping \(relPath) (not found)")
                continue
            }
            
            let destPath = "\(tmpDir)/\(relPath)"
            let destParent = (destPath as NSString).deletingLastPathComponent
            try? FileManager.default.createDirectory(atPath: destParent, withIntermediateDirectories: true)
            
            do {
                if FileManager.default.fileExists(atPath: destPath) {
                    try FileManager.default.removeItem(atPath: destPath)
                }
                try FileManager.default.copyItem(atPath: srcPath, toPath: destPath)
                await log("✅ Copied \(relPath)")
                copiedPaths.append(relPath)
            } catch {
                await log("⚠️ Could not copy \(relPath): \(error.localizedDescription)")
            }
        }
        
        // Copy LaunchAgents
        await setProgress(0.55)
        let launchAgentsDir = "\(home)/Library/LaunchAgents"
        if let agents = try? FileManager.default.contentsOfDirectory(atPath: launchAgentsDir) {
            let clawAgents = agents.filter { $0.hasPrefix("dev.clawrence.") || $0.contains("openclaw") }
            if !clawAgents.isEmpty {
                try? FileManager.default.createDirectory(atPath: "\(tmpDir)/LaunchAgents", withIntermediateDirectories: true)
                for agent in clawAgents {
                    let src = "\(launchAgentsDir)/\(agent)"
                    let dst = "\(tmpDir)/LaunchAgents/\(agent)"
                    try? FileManager.default.copyItem(atPath: src, toPath: dst)
                    await log("✅ Copied LaunchAgent: \(agent)")
                }
            }
        }
        
        await setProgress(0.65)
        await log("📦 Creating archive...")
        
        // Create tar.gz
        let result = await runShell("tar -czf '\(outputFile)' -C '\(tmpDir)' .")
        
        if result.exitCode == 0 {
            await setProgress(0.9)
            
            // Cleanup temp dir
            try? FileManager.default.removeItem(atPath: tmpDir)
            
            // Get file size
            let attrs = try? FileManager.default.attributesOfItem(atPath: outputFile)
            let size = attrs?[.size] as? Int64 ?? 0
            let sizeMB = String(format: "%.1f", Double(size) / 1024 / 1024)
            
            await setProgress(1.0)
            await log("✅ Backup complete!")
            await log("📍 Saved to: ~/Desktop/SaferClaw-backup-\(dateStr).tar.gz")
            await log("📏 Size: \(sizeMB) MB")
            await log("")
            await log("⚡ Next: AirDrop this file to your new Mac, then run Restore")
            isComplete = true
        } else {
            await log("❌ tar failed: \(result.stderr)")
            hasFailed = true
        }
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
