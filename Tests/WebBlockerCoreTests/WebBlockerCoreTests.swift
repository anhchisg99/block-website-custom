import Foundation
import Testing
@testable import WebBlockerCore

@Suite struct ScheduleTests {
    let mon = 2, tue = 3, sun = 1, sat = 7

    @Test func daytimeWindow() {
        let s = BlockSchedule(weekdays: [mon], startMinute: 9 * 60, endMinute: 17 * 60)
        #expect(s.isActive(weekday: mon, minute: 9 * 60))
        #expect(s.isActive(weekday: mon, minute: 16 * 60 + 59))
        #expect(!s.isActive(weekday: mon, minute: 17 * 60))
        #expect(!s.isActive(weekday: mon, minute: 8 * 60 + 59))
        #expect(!s.isActive(weekday: tue, minute: 10 * 60))
    }

    @Test func overnightWindowSpillsIntoNextDay() {
        let s = BlockSchedule(weekdays: [sat], startMinute: 22 * 60, endMinute: 2 * 60)
        #expect(s.isActive(weekday: sat, minute: 23 * 60))
        #expect(s.isActive(weekday: sun, minute: 60))       // Saturday night → Sunday 01:00
        #expect(!s.isActive(weekday: sun, minute: 2 * 60))
        #expect(!s.isActive(weekday: sat, minute: 60))      // Saturday 01:00 belongs to Friday's window
    }

    @Test func equalStartEndMeansWholeDay() {
        let s = BlockSchedule(weekdays: [mon], startMinute: 0, endMinute: 0)
        #expect(s.isActive(weekday: mon, minute: 0))
        #expect(s.isActive(weekday: mon, minute: 23 * 60 + 59))
        #expect(!s.isActive(weekday: tue, minute: 0))
    }

    @Test func disabledScheduleNeverActive() {
        let s = BlockSchedule(weekdays: [mon], startMinute: 0, endMinute: 0, isEnabled: false)
        #expect(!s.isActive(weekday: mon, minute: 600))
    }

    @Test func configRequiresEnabledAndSites() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        // 2026-11-23 is a Monday.
        let monday10am = cal.date(from: DateComponents(year: 2026, month: 11, day: 23, hour: 10))!
        var config = BlockConfig.initial
        #expect(!config.isBlocking(at: monday10am, calendar: cal))   // no sites yet
        config.sites = ["facebook.com"]
        #expect(config.isBlocking(at: monday10am, calendar: cal))
        config.isEnabled = false
        #expect(!config.isBlocking(at: monday10am, calendar: cal))
    }
}

@Suite struct DomainTests {
    @Test(arguments: [
        ("facebook.com", "facebook.com"),
        ("  https://www.Facebook.com/abc?x=1 ", "facebook.com"),
        ("http://user@m.youtube.com:8080/watch", "m.youtube.com"),
        ("reddit.com.", "reddit.com"),
        ("xn--bcher-kva.example", "xn--bcher-kva.example"),
    ])
    func normalizes(input: String, expected: String) {
        #expect(Domain.normalize(input) == expected)
    }

    @Test(arguments: ["", "localhost", "192.168.1.1", "-bad.com", "a..com", "evil.com\n0.0.0.0 apple.com", "foo bar.com", "tiếng.vn"])
    func rejects(input: String) {
        #expect(Domain.normalize(input) == nil)
    }
}

@Suite struct HostsFileTests {
    let original = "127.0.0.1\tlocalhost\n::1 localhost\n"

    @Test func addsSectionAndIsIdempotent() {
        let once = HostsFile.render(original: original, blocking: ["facebook.com"])
        #expect(once.hasPrefix(original))
        #expect(once.contains("0.0.0.0 facebook.com\n"))
        #expect(once.contains(":: www.facebook.com\n"))
        #expect(HostsFile.render(original: once, blocking: ["facebook.com"]) == once)
    }

    @Test func removingRestoresOriginal() {
        let blocked = HostsFile.render(original: original, blocking: ["a.com", "b.com"])
        #expect(HostsFile.render(original: blocked, blocking: []) == original)
    }

    @Test func preservesUserLinesAfterSection() {
        let blocked = HostsFile.render(original: original, blocking: ["a.com"]) + "10.0.0.5 nas.local\n"
        let updated = HostsFile.render(original: blocked, blocking: ["b.com"])
        #expect(updated.contains("10.0.0.5 nas.local"))
        #expect(!updated.contains("a.com"))
        #expect(updated.contains("0.0.0.0 b.com"))
    }

    @Test func dropsInvalidAndDuplicateDomains() {
        let out = HostsFile.render(original: original, blocking: ["a.com", "a.com", "x.com\n1.2.3.4 apple.com"])
        #expect(out.components(separatedBy: "0.0.0.0 a.com\n").count == 2)
        #expect(!out.contains("apple.com"))
    }

    @Test func readsBlockedHosts() {
        #expect(HostsFile.blockedHosts(in: original).isEmpty)
        let blocked = HostsFile.render(original: original, blocking: ["a.com"])
        #expect(HostsFile.blockedHosts(in: blocked) == ["a.com", "www.a.com"])
    }

    @Test func handlesMissingTrailingNewline() {
        let out = HostsFile.render(original: "127.0.0.1 localhost", blocking: ["a.com"])
        #expect(out.hasPrefix("127.0.0.1 localhost\n# >>> WebBlocker"))
    }
}
