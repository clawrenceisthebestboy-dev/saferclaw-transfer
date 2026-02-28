import SwiftUI

struct ContentView: View {
    @StateObject private var backupManager = BackupManager()
    @StateObject private var restoreManager = RestoreManager()
    
    @State private var showingRestorePicker = false
    @State private var activeOperation: Operation? = nil
    
    enum Operation { case backup, restore }
    
    var currentManager: (any OperationManager)? {
        switch activeOperation {
        case .backup: return backupManager
        case .restore: return restoreManager
        case nil: return nil
        }
    }
    
    var body: some View {
        ZStack {
            Color(hex: "#1a1a1a").ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                headerView
                
                Divider().background(Color(hex: "#c9a96e").opacity(0.3))
                
                // Instructions
                instructionsView
                
                Divider().background(Color(hex: "#c9a96e").opacity(0.3))
                
                // Main buttons
                if activeOperation == nil {
                    buttonsView
                } else {
                    progressView
                }
                
                Spacer()
                
                // Footer
                footerView
            }
        }
        .fileImporter(
            isPresented: $showingRestorePicker,
            allowedContentTypes: [.init(filenameExtension: "gz")!],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    activeOperation = .restore
                    restoreManager.start(from: url)
                }
            case .failure(let error):
                print("Picker error: \(error)")
            }
        }
    }
    
    var headerView: some View {
        HStack(spacing: 16) {
            Text("🦞")
                .font(.system(size: 48))
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("SaferClaw Transfer")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Transfer Edition — Free")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(hex: "#1a1a1a"))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(hex: "#c9a96e"))
                        .clipShape(Capsule())
                }
                
                Text("Clone your OpenClaw setup from one Mac to another")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
    }
    
    var instructionsView: some View {
        HStack(spacing: 0) {
            ForEach([
                ("1", "Run Backup", "on your old Mac"),
                ("2", "AirDrop the .tar.gz", "to your new Mac"),
                ("3", "Run Restore", "on your new Mac")
            ], id: \.0) { num, title, sub in
                HStack(spacing: 10) {
                    Text(num)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(hex: "#1a1a1a"))
                        .frame(width: 24, height: 24)
                        .background(Color(hex: "#c9a96e"))
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 1) {
                        Text(title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                        Text(sub)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .frame(maxWidth: .infinity)
                
                if num != "3" {
                    Image(systemName: "arrow.right")
                        .foregroundColor(Color(hex: "#c9a96e").opacity(0.5))
                        .font(.system(size: 11))
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 14)
        .background(Color(hex: "#c9a96e").opacity(0.07))
    }
    
    var buttonsView: some View {
        HStack(spacing: 20) {
            // Backup Button
            Button(action: {
                activeOperation = .backup
                backupManager.start()
            }) {
                VStack(spacing: 14) {
                    Image(systemName: "arrow.up.doc.fill")
                        .font(.system(size: 36))
                        .foregroundColor(Color(hex: "#c9a96e"))
                    
                    Text("Backup This Mac")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Packages your OpenClaw setup\ninto a single .tar.gz file")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .background(Color(hex: "#c9a96e").opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: "#c9a96e").opacity(0.3), lineWidth: 1.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            
            // Restore Button
            Button(action: {
                showingRestorePicker = true
            }) {
                VStack(spacing: 14) {
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: 36))
                        .foregroundColor(Color(hex: "#c9a96e"))
                    
                    Text("Restore From Backup")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Extracts your backup and\nreinstalls OpenClaw if needed")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .background(Color(hex: "#c9a96e").opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: "#c9a96e").opacity(0.3), lineWidth: 1.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
        }
        .padding(.horizontal, 28)
        .padding(.top, 28)
    }
    
    var progressView: some View {
        VStack(alignment: .leading, spacing: 16) {
            let manager = activeOperation == .backup ? backupManager as (any OperationManager) : restoreManager as (any OperationManager)
            
            HStack {
                Image(systemName: activeOperation == .backup ? "arrow.up.doc.fill" : "arrow.down.doc.fill")
                    .foregroundColor(Color(hex: "#c9a96e"))
                Text(activeOperation == .backup ? "Backing up..." : "Restoring...")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                if manager.isComplete {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 18))
                } else if manager.hasFailed {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 18))
                } else {
                    ProgressView()
                        .scaleEffect(0.7)
                        .tint(Color(hex: "#c9a96e"))
                }
            }
            
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "#c9a96e"))
                        .frame(width: geo.size.width * manager.progress, height: 6)
                        .animation(.easeInOut(duration: 0.3), value: manager.progress)
                }
            }
            .frame(height: 6)
            
            // Log
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(manager.logs.indices, id: \.self) { i in
                            Text(manager.logs[i])
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(manager.logs[i].hasPrefix("✅") ? .green :
                                               manager.logs[i].hasPrefix("❌") ? .red :
                                               manager.logs[i].hasPrefix("⚡") ? Color(hex: "#c9a96e") :
                                               .white.opacity(0.7))
                                .id(i)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                }
                .frame(height: 160)
                .background(Color.black.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onChange(of: manager.logs.count) { _ in
                    if let last = manager.logs.indices.last {
                        withAnimation { proxy.scrollTo(last) }
                    }
                }
            }
            
            if manager.isComplete || manager.hasFailed {
                Button(action: { activeOperation = nil }) {
                    Text("← Back")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(hex: "#c9a96e"))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 24)
    }
    
    var footerView: some View {
        HStack {
            Text("No account needed · No license key · Just works")
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.3))
            Spacer()
            Text("saferclaw.com")
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "#c9a96e").opacity(0.5))
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 16)
    }
}

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255.0,
            green: Double((rgb >> 8) & 0xFF) / 255.0,
            blue: Double(rgb & 0xFF) / 255.0
        )
    }
}

protocol OperationManager: ObservableObject {
    var progress: Double { get }
    var logs: [String] { get }
    var isComplete: Bool { get }
    var hasFailed: Bool { get }
}
