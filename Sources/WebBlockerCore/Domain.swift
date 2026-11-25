import Foundation

public enum Domain {
    /// Turns user input like "https://www.Facebook.com/abc" into "facebook.com".
    /// Returns nil if the result is not a valid hostname.
    public static func normalize(_ input: String) -> String? {
        var s = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let r = s.range(of: "://") { s = String(s[r.upperBound...]) }
        if let i = s.firstIndex(where: { "/?#".contains($0) }) { s = String(s[..<i]) }
        if let i = s.lastIndex(of: "@") { s = String(s[s.index(after: i)...]) }
        if let i = s.firstIndex(of: ":") { s = String(s[..<i]) }
        if s.hasSuffix(".") { s.removeLast() }
        if s.hasPrefix("www.") { s.removeFirst(4) }
        return isValid(s) ? s : nil
    }

    /// Strict ASCII hostname check. Also guards what the root daemon writes into /etc/hosts.
    public static func isValid(_ domain: String) -> Bool {
        guard domain.count <= 253 else { return false }
        let labels = domain.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2 else { return false }
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789-")
        for label in labels {
            guard (1...63).contains(label.count),
                  label.allSatisfy(allowed.contains),
                  label.first != "-", label.last != "-"
            else { return false }
        }
        // A numeric TLD means an IP address, not a domain.
        return labels.last!.contains { $0.isLetter }
    }
}
