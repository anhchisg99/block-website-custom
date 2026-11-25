import Foundation
import WebBlockerCore

enum Daemon {
    static let hostsPath = "/etc/hosts"

    static func apply(configPath: String) -> Int32 {
        // A missing or unreadable config means "block nothing".
        var domains: [String] = []
        if let data = FileManager.default.contents(atPath: configPath),
           let config = try? JSONDecoder().decode(BlockConfig.self, from: data),
           config.isBlocking(at: Date()) {
            domains = config.sites
        }
        return writeHosts(blocking: domains)
    }

    static func writeHosts(blocking domains: [String]) -> Int32 {
        // Never write if we could not read: that would wipe the user's hosts file.
        guard let original = try? String(contentsOfFile: hostsPath, encoding: .utf8) else {
            FileHandle.standardError.write(Data("webblockerd: cannot read \(hostsPath)\n".utf8))
            return 1
        }
        let updated = HostsFile.render(original: original, blocking: domains)
        guard updated != original else { return 0 }
        do {
            try updated.write(toFile: hostsPath, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: hostsPath)
        } catch {
            FileHandle.standardError.write(Data("webblockerd: \(error)\n".utf8))
            return 1
        }
        run("/usr/bin/dscacheutil", ["-flushcache"])
        run("/usr/bin/killall", ["-HUP", "mDNSResponder"])

        // Something new got blocked: make browsers drop their open connections and DNS cache.
        let before = HostsFile.blockedHosts(in: original)
        if !HostsFile.blockedHosts(in: updated).isSubset(of: before) {
            resetBrowserNetworking()
        }
        return 0
    }

    /// Browsers keep connections (and their own DNS cache) open, so a site opened before the
    /// block starts would keep working. Killing the browser's network process makes the browser
    /// restart it immediately; tabs stay open, but every new request resolves through /etc/hosts.
    /// Only browser helpers are matched — Electron apps (VS Code, Zalo, Spotify…) use the same
    /// network-service flag and must not be touched.
    private static func resetBrowserNetworking() {
        let chromiumHelpers = [
            "Google Chrome Helper", "Microsoft Edge Helper", "Brave Browser Helper",
            "Arc Helper", "Chromium Helper", "Vivaldi Helper", "Opera Helper", "Dia Helper",
        ]
        for helper in chromiumHelpers {
            run("/usr/bin/pkill", ["-9", "-f", "/\(helper).*--utility-sub-type=network\\.mojom\\.NetworkService"])
        }
        // Safari (and other WebKit apps) — WebKit relaunches its networking process on demand.
        run("/usr/bin/pkill", ["-9", "-x", "com.apple.WebKit.Networking"])
    }

    private static func run(_ path: String, _ arguments: [String]) {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = arguments
        try? p.run()
        p.waitUntilExit()
    }
}
