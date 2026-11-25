import Foundation
import Observation
import WebBlockerCore

@MainActor @Observable
final class BlockStore {
    var config: BlockConfig { didSet { save() } }
    private(set) var now = Date()
    private(set) var helperInstalled = HelperInstaller.isInstalled
    private(set) var isWorking = false
    var errorMessage: String?

    var isBlocking: Bool { config.isBlocking(at: now) }

    static let configURL: URL = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("WebBlocker", isDirectory: true)
        .appendingPathComponent("config.json")

    init() {
        if let data = try? Data(contentsOf: Self.configURL),
           let saved = try? JSONDecoder().decode(BlockConfig.self, from: data) {
            config = saved
        } else {
            config = .initial
            save()
        }
        Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                self?.now = Date()
            }
        }
    }

    // MARK: Sites

    /// Returns an error message, or nil on success.
    func addSite(_ input: String) -> String? {
        guard let domain = Domain.normalize(input) else {
            return "“\(input.trimmingCharacters(in: .whitespaces))” không phải tên miền hợp lệ"
        }
        guard !config.sites.contains(domain) else { return "\(domain) đã có trong danh sách" }
        config.sites.append(domain)
        return nil
    }

    func removeSite(_ domain: String) {
        config.sites.removeAll { $0 == domain }
    }

    // MARK: Schedules

    func addSchedule() {
        config.schedules.append(BlockSchedule(weekdays: [2, 3, 4, 5, 6], startMinute: 9 * 60, endMinute: 17 * 60))
    }

    func removeSchedule(_ id: UUID) {
        config.schedules.removeAll { $0.id == id }
    }

    // MARK: Helper

    func installHelper() async { await runHelperTask { try await HelperInstaller.install(configURL: Self.configURL) } }
    func uninstallHelper() async { await runHelperTask { try await HelperInstaller.uninstall() } }

    private func runHelperTask(_ work: () async throws -> Void) async {
        isWorking = true
        defer {
            isWorking = false
            helperInstalled = HelperInstaller.isInstalled
        }
        do {
            try await work()
        } catch let error as InstallerError where error.isUserCancel {
            // User dismissed the password prompt.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: Persistence

    private func save() {
        do {
            try FileManager.default.createDirectory(at: Self.configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(config).write(to: Self.configURL, options: .atomic)
        } catch {
            errorMessage = "Không lưu được cấu hình: \(error.localizedDescription)"
        }
    }
}
