import Foundation

/// Manages a marked section inside /etc/hosts, leaving everything else untouched.
public enum HostsFile {
    static let beginMarker = "# >>> WebBlocker (managed automatically, do not edit) >>>"
    static let endMarker = "# <<< WebBlocker <<<"

    /// Hostnames currently listed in the WebBlocker section of `contents`.
    public static func blockedHosts(in contents: String) -> Set<String> {
        var hosts = Set<String>()
        var insideSection = false
        for line in contents.split(separator: "\n", omittingEmptySubsequences: false) {
            if line == beginMarker { insideSection = true; continue }
            if line == endMarker { insideSection = false; continue }
            if insideSection, let host = line.split(separator: " ").last { hosts.insert(String(host)) }
        }
        return hosts
    }

    /// Returns `original` with the WebBlocker section replaced by entries for `domains`
    /// (or removed entirely when `domains` is empty).
    public static func render(original: String, blocking domains: [String]) -> String {
        var kept: [Substring] = []
        var insideSection = false
        for line in original.split(separator: "\n", omittingEmptySubsequences: false) {
            if line == beginMarker { insideSection = true; continue }
            if line == endMarker { insideSection = false; continue }
            if !insideSection { kept.append(line) }
        }
        var result = kept.joined(separator: "\n")
        if !result.isEmpty && !result.hasSuffix("\n") { result += "\n" }

        var seen = Set<String>()
        let valid = domains.filter { Domain.isValid($0) && seen.insert($0).inserted }
        guard !valid.isEmpty else { return result }

        var section = [beginMarker]
        for domain in valid {
            for host in [domain, "www." + domain] {
                section.append("0.0.0.0 \(host)")
                section.append(":: \(host)")
            }
        }
        section.append(endMarker)
        return result + section.joined(separator: "\n") + "\n"
    }
}
