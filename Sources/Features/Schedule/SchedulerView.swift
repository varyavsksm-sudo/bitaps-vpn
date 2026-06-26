import SwiftUI

/// Auto connect/disconnect by time — a list of `ScheduleRule`s plus a sheet to
/// add new ones. Pushed inside an existing NavigationStack, so it uses
/// `.navigationTitle` and never creates its own stack. iOS16 / macOS13 safe.
public struct SchedulerView: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var settings: Settings

    @State private var showAdd = false

    public init() {}

    public var body: some View {
        ZStack {
            BitBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    introCard
                    rulesSection
                    BitButton("Добавить правило", icon: "plus") { showAdd = true }
                }
                .padding(BitMetric.pad)
            }
        }
        .navigationTitle("Расписание")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showAdd) {
            AddScheduleSheet { rule in store.addSchedule(rule) }
                .environmentObject(store)
                .environmentObject(settings)
        }
    }

    // MARK: - Intro

    @ViewBuilder private var introCard: some View {
        BitCard(strong: true) {
            HStack(spacing: 14) {
                GradientIcon("clock.fill", index: 0, size: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Авто-подключение по времени")
                        .font(BitFont.display(17, weight: .semibold))
                        .foregroundStyle(BitColor.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("bitaps сам включит или выключит защиту по вашему графику — будни, выходные или каждый день.")
                        .font(BitFont.mono(12))
                        .foregroundStyle(BitColor.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .bitGlow(BitColor.accent, radius: 24, opacity: 0.18)
    }

    // MARK: - Rules

    @ViewBuilder private var rulesSection: some View {
        VStack(alignment: .leading, spacing: BitMetric.gap) {
            Kicker("правила")
            if store.schedules.isEmpty {
                BitCard {
                    HStack(spacing: 12) {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundStyle(BitColor.muted)
                        Text("Пока нет правил — добавьте первое ниже.")
                            .font(BitFont.mono(12))
                            .foregroundStyle(BitColor.muted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ForEach(Array(store.schedules.enumerated()), id: \.element.id) { idx, rule in
                    ruleRow(rule, index: idx)
                }
            }
        }
    }

    @ViewBuilder private func ruleRow(_ rule: ScheduleRule, index: Int) -> some View {
        let glow = BitColor.chipShadow(index)
        BitCard {
            VStack(spacing: 12) {
                HStack(spacing: 14) {
                    GradientIcon(rule.action.icon, index: index, size: 40)
                        .saturation(rule.enabled ? 1 : 0)
                        .opacity(rule.enabled ? 1 : 0.5)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(rule.timeString)
                            .font(BitFont.display(26, weight: .bold))
                            .foregroundStyle(LinearGradient(colors: [BitColor.accentSoft, glow],
                                                            startPoint: .top, endPoint: .bottom))
                            .bitGlow(glow, radius: 12, opacity: rule.enabled ? 0.3 : 0)
                        HStack(spacing: 8) {
                            Text(rule.action.label)
                                .font(BitFont.display(13, weight: .semibold))
                                .foregroundStyle(BitColor.text)
                            Text(rule.daysString)
                                .font(BitFont.mono(12))
                                .foregroundStyle(BitColor.muted)
                        }
                    }
                    Spacer(minLength: 8)
                    Button {
                        store.removeSchedule(rule)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(BitColor.danger)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(BitColor.danger.opacity(0.12)))
                    }
                    .buttonStyle(.plain)
                }
                Rectangle().fill(BitColor.line).frame(height: 1)
                BitToggle("Активно", systemImage: "bolt.fill",
                          isOn: Binding(get: { rule.enabled },
                                        set: { _ in store.toggleSchedule(rule) }))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .opacity(rule.enabled ? 1 : 0.75)
        .bitGlow(rule.enabled ? glow : .clear, radius: 18, opacity: rule.enabled ? 0.18 : 0)
    }
}

// MARK: - Add rule sheet

private struct AddScheduleSheet: View {
    @EnvironmentObject var store: AppStore
    @EnvironmentObject var settings: Settings
    @Environment(\.dismiss) private var dismiss

    let onSave: (ScheduleRule) -> Void

    @State private var time = Date()
    @State private var action: ScheduleAction = .connect
    @State private var days: Set<Int> = [1, 2, 3, 4, 5]

    private let dayNames = ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]

    var body: some View {
        ZStack {
            BitBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header

                    BitCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Kicker("время")
                            DatePicker("Когда", selection: $time, displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .datePickerStyle(.graphical)
                                .tint(BitColor.accent)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    BitCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Kicker("действие")
                            Picker("Действие", selection: $action) {
                                ForEach(ScheduleAction.allCases) { a in
                                    Text(a.label).tag(a)
                                }
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    BitCard {
                        VStack(alignment: .leading, spacing: 14) {
                            Kicker("дни недели")
                            ViewThatFits(in: .horizontal) {
                                HStack(spacing: 8) { dayChips }
                                VStack(spacing: 8) {
                                    HStack(spacing: 8) { dayChip(0); dayChip(1); dayChip(2); dayChip(3) }
                                    HStack(spacing: 8) { dayChip(4); dayChip(5); dayChip(6) }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    BitButton("Сохранить", icon: "checkmark") { save() }
                        .disabled(days.isEmpty)
                        .opacity(days.isEmpty ? 0.5 : 1)
                }
                .padding(BitMetric.pad)
            }
        }
        #if os(iOS)
        .presentationDetents([.large])
        #endif
    }

    @ViewBuilder private var header: some View {
        HStack(spacing: 14) {
            GradientIcon(action.icon, index: action == .connect ? 0 : 3, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("Новое правило")
                    .font(BitFont.display(20, weight: .bold))
                    .foregroundStyle(BitColor.text)
                Text("выберите время, действие и дни")
                    .font(BitFont.mono(12))
                    .foregroundStyle(BitColor.muted)
            }
            Spacer(minLength: 8)
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(BitColor.muted)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(BitColor.panel))
                    .overlay(Circle().stroke(BitColor.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder private var dayChips: some View {
        ForEach(0..<7, id: \.self) { i in dayChip(i) }
    }

    @ViewBuilder private func dayChip(_ i: Int) -> some View {
        let day = i + 1
        let on = days.contains(day)
        Button {
            if on { days.remove(day) } else { days.insert(day) }
        } label: {
            Text(dayNames[i])
                .font(BitFont.mono(13, weight: .semibold))
                .frame(width: 40, height: 40)
                .foregroundStyle(on ? Color.black : BitColor.text)
                .background(
                    Circle().fill(on ? AnyShapeStyle(BitColor.accentGradient)
                                     : AnyShapeStyle(BitColor.panel))
                )
                .overlay(Circle().stroke(on ? Color.clear : BitColor.line, lineWidth: 1))
                .bitGlow(on ? BitColor.accent : .clear, radius: 12, opacity: on ? 0.4 : 0)
        }
        .buttonStyle(.plain)
    }

    private func save() {
        let cal = Calendar.current
        let hour = cal.component(.hour, from: time)
        let minute = cal.component(.minute, from: time)
        onSave(ScheduleRule(action: action, hour: hour, minute: minute, days: days))
        dismiss()
    }
}

#if DEBUG
struct SchedulerView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            SchedulerView()
                .environmentObject(AppStore())
                .environmentObject(Settings())
        }
        .preferredColorScheme(.dark)
    }
}
#endif
