import Foundation

/// Installs a root LaunchDaemon that re-applies the schedule every minute and
/// whenever the config folder changes. Requires the admin password once.
enum HelperInstaller {
    static let label = "com.webblocker.daemon"
    static let plistPath = "/Library/LaunchDaemons/\(label).plist"
    static let helperDir = "/Library/Application Support/WebBlocker"
    static let helperPath = helperDir + "/webblockerd"

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: plistPath) && FileManager.default.fileExists(atPath: helperPath)
    }

    static func install(configURL: URL) async throws {
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [helperPath, "--apply", configURL.path],
            "RunAtLoad": true,
            "StartInterval": 60,
            "WatchPaths": [configURL.deletingLastPathComponent().path],
        ]
        let plistData = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
        let executable = Bundle.main.executablePath!

        let script = [
            "set -e",
            "mkdir -p \(q(helperDir))",
            "install -o root -g wheel -m 755 \(q(executable)) \(q(helperPath))",
            "echo \(plistData.base64EncodedString()) | base64 -D > \(q(plistPath))",
            "chown root:wheel \(q(plistPath))",
            "chmod 644 \(q(plistPath))",
            "launchctl bootout system/\(label) 2>/dev/null || true",
            "launchctl bootstrap system \(q(plistPath)) || { sleep 2; launchctl bootstrap system \(q(plistPath)); }",
        ].joined(separator: "\n")
        try await runAsAdmin(script)
    }

    static func uninstall() async throws {
        let script = [
            "launchctl bootout system/\(label) 2>/dev/null || true",
            "[ -x \(q(helperPath)) ] && \(q(helperPath)) --clear || true",
            "rm -f \(q(plistPath))",
            "rm -rf \(q(helperDir))",
        ].joined(separator: "\n")
        try await runAsAdmin(script)
    }

    // MARK: - Helpers

    /// Single-quotes a string for /bin/sh.
    private static func q(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func runAsAdmin(_ shellScript: String) async throws {
        let escaped = shellScript
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let appleScript = "do shell script \"\(escaped)\" with administrator privileges"

        try await Task.detached {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            p.arguments = ["-e", appleScript]
            let stderr = Pipe()
            p.standardError = stderr
            try p.run()
            p.waitUntilExit()
            guard p.terminationStatus == 0 else {
                let message = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                throw InstallerError(message: message.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }.value
    }
}

struct InstallerError: LocalizedError {
    let message: String
    var isUserCancel: Bool { message.contains("-128") }
    var errorDescription: String? { message.isEmpty ? "Không rõ lỗi" : message }
}
