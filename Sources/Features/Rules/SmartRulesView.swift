import SwiftUI

/// «Умные правила» — per-domain/app routing: через VPN / напрямую / блок.
public struct SmartRulesView: View {
    @EnvironmentObject var store: AppStore
    @State private var pattern = ""
    @State private var action: RuleAction = .viaVPN
    public init() {}

    public var body: some View {
        ZStack {
            BitBackground()
            ScrollView {
                VStack(spacing: BitMetric.gap) {
                    BitCard {
                        HStack(spacing: 12) {
                            GradientIcon("arrow.triangle.branch", index: 1, size: 40)
                            Text("Домен или приложение → через VPN, напрямую или блок. Нажмите на тег, чтобы сменить действие.")
                                .font(BitFont.mono(12)).foregroundStyle(BitColor.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    addCard

                    ForEach(store.smartRules) { rule in
                        BitCard(padding: 12) {
                            HStack(spacing: 12) {
                                Text(LocalizedStringKey(rule.pattern)).font(BitFont.mono(13, weight: .medium))
                                    .foregroundStyle(BitColor.text).lineLimit(1)
                                Spacer(minLength: 8)
                                Button { store.cycleRuleAction(rule) } label: {
                                    Text(LocalizedStringKey(rule.action.label))
                                        .font(BitFont.mono(11, weight: .semibold))
                                        .padding(.horizontal, 10).padding(.vertical, 6)
                                        .foregroundStyle(Color(hex: rule.action.hex))
                                        .background(Capsule().fill(Color(hex: rule.action.hex).opacity(0.16)))
                                }
                                .buttonStyle(.plain)
                                Button { store.removeRule(rule) } label: {
                                    Image(systemName: "trash").font(.system(size: 14)).foregroundStyle(BitColor.muted)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "info.circle").font(.system(size: 11))
                        Text("Правила сохраняются и применятся при подключении через боевое VPN-ядро.")
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(BitFont.mono(11)).foregroundStyle(BitColor.muted)
                    .padding(.horizontal, 4).padding(.top, 2)
                }
                .padding(BitMetric.pad)
                .frame(maxWidth: 560).frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("Умные правила")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var addCard: some View {
        BitCard {
            VStack(alignment: .leading, spacing: 12) {
                Kicker("новое правило")
                TextField("домен или приложение", text: $pattern)
                    .font(BitFont.mono(14)).foregroundStyle(BitColor.text)
                    .padding(.horizontal, 12).padding(.vertical, 11)
                    .background(RoundedRectangle(cornerRadius: BitMetric.radiusSmall, style: .continuous).fill(BitColor.panelStrong))
                    .overlay(RoundedRectangle(cornerRadius: BitMetric.radiusSmall, style: .continuous).stroke(BitColor.line, lineWidth: 1))
                    #if os(iOS)
                    .autocorrectionDisabled(true)
                    .textInputAutocapitalization(.never)
                    #endif
                Picker("Действие", selection: $action) {
                    ForEach(RuleAction.allCases) { a in Text(LocalizedStringKey(a.label)).tag(a) }
                }
                .pickerStyle(.segmented).labelsHidden()
                BitButton("Добавить", icon: "plus", kind: .solid) {
                    store.addRule(pattern: pattern, action: action)
                    pattern = ""
                }
            }
        }
    }
}
