import SwiftUI

struct SitesSection: View {
    @Environment(BlockStore.self) private var store
    @ViewState private var input = ""
    @ViewState private var error: String?
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Website bị chặn", systemImage: "globe")

            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("Nhập tên miền, ví dụ facebook.com", text: $input)
                            .textFieldStyle(.plain)
                            .focused($fieldFocused)
                            .onSubmit(add)
                            .onChange(of: input) { error = nil }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 11)
                    .glassEffect(.regular.interactive(), in: .capsule)

                    Button(action: add) {
                        Label("Thêm", systemImage: "plus")
                            .padding(.horizontal, 4)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .disabled(input.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }

            if let error {
                Label(error, systemImage: "exclamationmark.circle")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 6)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if store.config.sites.isEmpty {
                EmptyHint(text: "Chưa có website nào. Tên miền sẽ được chặn cùng với “www.”.")
            } else {
                GlassEffectContainer(spacing: 10) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 10)], spacing: 10) {
                        ForEach(store.config.sites, id: \.self) { site in
                            SiteChip(domain: site) { store.removeSite(site) }
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                }
            }
        }
        .animation(.smooth, value: error)
    }

    private func add() {
        if let message = store.addSite(input) {
            error = message
        } else {
            input = ""
            error = nil
            fieldFocused = true
        }
    }
}

private struct SiteChip: View {
    let domain: String
    let onDelete: () -> Void
    @ViewState private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            Text(domain.prefix(1).uppercased())
                .font(.system(.callout, design: .rounded, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(Circle().fill(color.gradient))
            Text(domain)
                .font(.callout.weight(.medium))
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .opacity(hovering ? 1 : 0.45)
            .help("Xoá \(domain)")
        }
        .padding(.leading, 8)
        .padding(.trailing, 12)
        .padding(.vertical, 8)
        .glassEffect(.regular.interactive(), in: .capsule)
        .onHover { hovering = $0 }
    }

    /// Stable per-domain colour for the monogram.
    private var color: Color {
        let palette: [Color] = [.red, .orange, .pink, .purple, .indigo, .blue, .teal, .green]
        let sum = domain.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return palette[sum % palette.count]
    }
}

struct EmptyHint: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .glassEffect(.clear, in: .rect(cornerRadius: 20))
    }
}
