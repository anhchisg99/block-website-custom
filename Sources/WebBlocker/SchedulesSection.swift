import SwiftUI
import WebBlockerCore

struct SchedulesSection: View {
    @Environment(BlockStore.self) private var store

    var body: some View {
        @Bindable var store = store
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(
                title: "Lịch chặn trong tuần",
                systemImage: "calendar",
                trailing: AnyView(
                    Button("Thêm lịch", systemImage: "plus") { store.addSchedule() }
                        .buttonStyle(.glass)
                )
            )

            if store.config.schedules.isEmpty {
                EmptyHint(text: "Chưa có lịch nào. Website chỉ bị chặn trong các khung giờ bạn đặt.")
            } else {
                ForEach($store.config.schedules) { $schedule in
                    ScheduleCard(schedule: $schedule) { store.removeSchedule(schedule.id) }
                        .transition(.scale(scale: 0.95).combined(with: .opacity))
                }
            }
        }
    }
}

private struct ScheduleCard: View {
    @Binding var schedule: BlockSchedule
    let onDelete: () -> Void

    /// Monday-first display order, mapped to Calendar weekday numbers.
    private static let days: [(weekday: Int, label: String)] = [
        (2, "T2"), (3, "T3"), (4, "T4"), (5, "T5"), (6, "T6"), (7, "T7"), (1, "CN"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "clock")
                    .foregroundStyle(.secondary)
                DatePicker("Bắt đầu", selection: time(\.startMinute), displayedComponents: .hourAndMinute)
                    .labelsHidden()
                Image(systemName: "arrow.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                DatePicker("Kết thúc", selection: time(\.endMinute), displayedComponents: .hourAndMinute)
                    .labelsHidden()
                if let note {
                    Text(note)
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .glassEffect(.regular.tint(.indigo.opacity(0.3)), in: .capsule)
                }
                Spacer()
                Toggle("Bật lịch", isOn: $schedule.isEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.glass)
                .help("Xoá lịch này")
            }

            GlassEffectContainer(spacing: 6) {
                HStack(spacing: 6) {
                    ForEach(Self.days, id: \.weekday) { day in
                        DayButton(label: day.label, isOn: schedule.weekdays.contains(day.weekday)) {
                            if schedule.weekdays.contains(day.weekday) {
                                schedule.weekdays.remove(day.weekday)
                            } else {
                                schedule.weekdays.insert(day.weekday)
                            }
                        }
                    }
                }
            }
        }
        .padding(18)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
        .opacity(schedule.isEnabled ? 1 : 0.6)
    }

    private var note: String? {
        if schedule.startMinute == schedule.endMinute { return "Cả ngày" }
        if schedule.startMinute > schedule.endMinute { return "Qua đêm" }
        return nil
    }

    private func time(_ keyPath: WritableKeyPath<BlockSchedule, Int>) -> Binding<Date> {
        Binding(
            get: {
                let minutes = schedule[keyPath: keyPath]
                return Calendar.current.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: .now) ?? .now
            },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                schedule[keyPath: keyPath] = (c.hour ?? 0) * 60 + (c.minute ?? 0)
            }
        )
    }
}

private struct DayButton: View {
    let label: String
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(.callout, design: .rounded, weight: .semibold))
                .foregroundStyle(isOn ? Color.white : Color.primary)
                .frame(width: 42, height: 42)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(isOn ? .regular.tint(.accentColor).interactive() : .regular.interactive(), in: .circle)
        .animation(.smooth(duration: 0.2), value: isOn)
    }
}
