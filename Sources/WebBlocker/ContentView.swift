import SwiftUI
import WebBlockerCore

struct ContentView: View {
    @Environment(BlockStore.self) private var store

    var body: some View {
        @Bindable var store = store
        ZStack {
            AmbientBackground(isBlocking: store.isBlocking)

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    StatusCard()
                    if !store.helperInstalled { HelperBanner() }
                    SitesSection()
                    SchedulesSection()
                    HelperFooter()
                }
                .padding(.horizontal, 28)
                .padding(.top, 44)
                .padding(.bottom, 28)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
        }
        .animation(.smooth(duration: 0.35), value: store.isBlocking)
        .animation(.smooth(duration: 0.3), value: store.config)
        .alert("Có lỗi xảy ra", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
    }
}

// MARK: - Background

/// Soft colour wash behind the glass so its refraction has something to show.
private struct AmbientBackground: View {
    let isBlocking: Bool

    var body: some View {
        let colors: [Color] = isBlocking ? [.orange, .pink, .purple] : [.teal, .blue, .indigo]
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            Circle().fill(colors[0]).frame(width: 420).blur(radius: 120).offset(x: -220, y: -280)
            Circle().fill(colors[1]).frame(width: 380).blur(radius: 130).offset(x: 260, y: 40)
            Circle().fill(colors[2]).frame(width: 460).blur(radius: 140).offset(x: -120, y: 380)
        }
        .opacity(0.55)
        .ignoresSafeArea()
    }
}

// MARK: - Status

private struct StatusCard: View {
    @Environment(BlockStore.self) private var store

    var body: some View {
        @Bindable var store = store
        HStack(spacing: 18) {
            Image(systemName: store.isBlocking ? "shield.lefthalf.filled" : "shield.slash")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(store.isBlocking ? Color.white : Color.secondary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 64, height: 64)
                .glassEffect(store.isBlocking ? .regular.tint(.orange) : .regular, in: .circle)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .contentTransition(.numericText())
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Toggle("Bật chặn", isOn: $store.config.isEnabled)
                .toggleStyle(.switch)
                .labelsHidden()
                .controlSize(.large)
        }
        .padding(22)
        .glassEffect(
            .regular.tint(store.isBlocking ? .orange.opacity(0.18) : .clear),
            in: .rect(cornerRadius: 28)
        )
    }

    private var title: String {
        store.isBlocking ? "Đang chặn \(store.config.sites.count) website" : "Không chặn"
    }

    private var subtitle: String {
        if !store.config.isEnabled { return "Đã tắt toàn bộ lịch chặn" }
        if store.config.sites.isEmpty { return "Thêm website để bắt đầu" }
        if !store.config.schedules.contains(where: \.isEnabled) { return "Chưa có lịch nào được bật" }
        return store.isBlocking ? "Trong khung giờ chặn" : "Ngoài khung giờ chặn"
    }
}

// MARK: - Helper install

private struct HelperBanner: View {
    @Environment(BlockStore.self) private var store

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "lock.shield")
                .font(.title2)
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text("Cần cài dịch vụ chặn").font(.headline)
                Text("Dịch vụ chạy nền sẽ áp dụng lịch chặn kể cả khi app đã đóng. Chỉ hỏi mật khẩu admin một lần.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Button {
                Task { await store.installHelper() }
            } label: {
                if store.isWorking { ProgressView().controlSize(.small) } else { Text("Cài đặt") }
            }
            .buttonStyle(.glassProminent)
            .controlSize(.large)
            .disabled(store.isWorking)
        }
        .padding(18)
        .glassEffect(.regular.tint(.yellow.opacity(0.12)), in: .rect(cornerRadius: 22))
    }
}

private struct HelperFooter: View {
    @Environment(BlockStore.self) private var store

    var body: some View {
        if store.helperInstalled {
            HStack(spacing: 10) {
                Label("Dịch vụ chặn đang chạy", systemImage: "checkmark.seal.fill")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        Button("Cài lại") { Task { await store.installHelper() } }
                        Button("Gỡ cài đặt", role: .destructive) { Task { await store.uninstallHelper() } }
                    }
                    .buttonStyle(.glass)
                    .disabled(store.isWorking)
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: String
    let systemImage: String
    var trailing: AnyView? = nil

    var body: some View {
        HStack {
            Label(title, systemImage: systemImage)
                .font(.system(.title3, design: .rounded, weight: .semibold))
            Spacer()
            trailing
        }
        .padding(.horizontal, 4)
    }
}
