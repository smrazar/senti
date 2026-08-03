import SwiftUI

/// Every option the bundled scrcpy understands that senti does not already surface, read from
/// its own `--help` at runtime.
///
/// This is the escape hatch. Anything switched on here is passed straight through, so the pane
/// says what it is doing and gives one button to undo all of it.
@MainActor
final class AdvancedFlagsModel: ObservableObject {
    @Published private(set) var flags: [ScrcpyFlag] = []
    @Published private(set) var isLoading = false
    @Published private(set) var failure: String?

    func load(scrcpyPath: String) async {
        guard flags.isEmpty, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        let parsed = await Task.detached(priority: .userInitiated) {
            ScrcpyFlags.load(scrcpyPath: scrcpyPath)
        }.value

        if parsed.isEmpty {
            failure = "scrcpy did not report its options. Try Help → Re-install the tools."
        } else {
            failure = nil
            flags = parsed
        }
    }
}

struct AdvancedSettingsView: View {

    @ObservedObject var state: AppState
    @ObservedObject private var preferences: Preferences
    @StateObject private var model = AdvancedFlagsModel()

    @State private var query = ""
    @State private var confirmingReset = false
    /// Value-taking flags whose field is open but still empty. They are deliberately *not*
    /// stored yet: `--angle` with no value makes scrcpy exit with a usage error, so a flag that
    /// needs a value only becomes real once one is typed.
    @State private var awaitingValue: Set<String> = []

    init(state: AppState) {
        self.state = state
        preferences = state.preferences
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s20) {
            toolbar
            warning

            if model.isLoading {
                EmptyState(symbol: "hourglass", title: "Reading scrcpy’s options…")
            } else if let failure = model.failure {
                EmptyState(symbol: Sym.warning, title: "Could not read the options", message: failure)
            } else if visible.isEmpty {
                EmptyState(symbol: Sym.search,
                           title: "Nothing matches “\(query)”",
                           message: "Search the flag name or its description.")
            } else {
                flagList
            }
        }
        .task { await model.load(scrcpyPath: state.toolchain.scrcpyPath) }
        .animation(Theme.Motion.standard, value: model.isLoading)
        .animation(Theme.Motion.fast, value: confirmingReset)
    }

    // MARK: Toolbar

    private var toolbar: some View {
        HStack(spacing: Theme.Space.s12) {
            HStack(spacing: Theme.Space.s8) {
                Image(systemName: Sym.search)
                    .font(.system(size: Theme.IconSize.inline))
                    .foregroundStyle(Theme.textTertiary)
                TextField("Search \(model.flags.count) options", text: $query)
                    .textFieldStyle(.plain)
                    .font(Theme.Font.body)
                    .foregroundStyle(Theme.textPrimary)
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: Theme.IconSize.inline))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.Space.s12)
            .frame(height: 30)
            .background(Theme.surfaceSecondary)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                    .strokeBorder(Theme.border, lineWidth: 1)
            )

            SecondaryButton(title: confirmingReset ? "Really reset?" : "Reset",
                            symbol: Sym.refresh,
                            destructive: enabledCount > 0) {
                if confirmingReset || enabledCount == 0 {
                    preferences.advancedFlagValues = [:]
                    awaitingValue = []
                    confirmingReset = false
                } else {
                    confirmingReset = true
                }
            }
        }
    }

    @ViewBuilder
    private var warning: some View {
        if enabledCount > 0 {
            HStack(alignment: .top, spacing: Theme.Space.s8) {
                Image(systemName: Sym.warning)
                    .font(.system(size: Theme.IconSize.inline))
                    .foregroundStyle(Theme.textTertiary)
                Text("\(enabledCount) option\(enabledCount == 1 ? "" : "s") passed straight to scrcpy. A bad value here makes a session fail to start — Reset clears them all.")
                    .font(Theme.Font.caption)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: List

    private var flagList: some View {
        LazyVStack(alignment: .leading, spacing: Theme.Space.section) {
            ForEach(groupedVisible, id: \.category) { group in
                SettingsGroup(title: "\(group.category.title)  ·  \(group.flags.count)",
                              symbol: group.category.symbol) {
                    ForEach(Array(group.flags.enumerated()), id: \.element.id) { index, flag in
                        if index > 0 { RowDivider() }
                        row(flag)
                    }
                }
            }
        }
    }

    private func row(_ flag: ScrcpyFlag) -> some View {
        let isOn = preferences.advancedFlagValues[flag.name] != nil || awaitingValue.contains(flag.name)
        return VStack(alignment: .leading, spacing: Theme.Space.s12) {
            SettingsRow(label: flag.short.map { "\(flag.name)  ·  \($0)" } ?? flag.name,
                        description: flag.summary.isEmpty ? nil : flag.summary) {
                SentiToggle(isOn: Binding(
                    get: { isOn },
                    set: { wanted in setEnabled(wanted, for: flag) }
                ))
            }

            if isOn && flag.takesValue {
                HStack(spacing: Theme.Space.s8) {
                    Text("=")
                        .font(Theme.Font.mono)
                        .foregroundStyle(Theme.textTertiary)
                    TextField(flag.valueLabel ?? "value", text: Binding(
                        get: { preferences.advancedFlagValues[flag.name] ?? "" },
                        set: { typed in
                            var values = preferences.advancedFlagValues
                            if typed.isEmpty {
                                values.removeValue(forKey: flag.name)
                                awaitingValue.insert(flag.name)
                            } else {
                                values[flag.name] = typed
                                awaitingValue.remove(flag.name)
                            }
                            preferences.advancedFlagValues = values
                        }
                    ))
                    .textFieldStyle(.plain)
                    .font(Theme.Font.mono)
                    .foregroundStyle(Theme.textPrimary)
                    .padding(.horizontal, Theme.Space.s12)
                    .frame(height: 30)
                    .background(Theme.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
                            .strokeBorder(Theme.border, lineWidth: 1)
                    )
                }
                .padding(.horizontal, Theme.Space.rowH)
                .padding(.bottom, Theme.Space.s12)
                .transition(.opacity)
            }
        }
        .animation(Theme.Motion.fast, value: isOn)
    }

    // MARK: Data

    private var visible: [ScrcpyFlag] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return model.flags }
        return model.flags.filter { flag in
            flag.name.range(of: trimmed, options: .caseInsensitive) != nil
                || flag.summary.range(of: trimmed, options: .caseInsensitive) != nil
        }
    }

    /// The visible flags bucketed, in category order, with empty buckets dropped — a search that
    /// matches three audio options should show one heading, not eight.
    private var groupedVisible: [(category: ScrcpyFlagCategory, flags: [ScrcpyFlag])] {
        let byCategory = Dictionary(grouping: visible, by: \.category)
        return ScrcpyFlagCategory.allCases.compactMap { category in
            guard let flags = byCategory[category], !flags.isEmpty else { return nil }
            return (category, flags)
        }
    }

    private var enabledCount: Int { preferences.advancedFlagValues.count }

    /// A switch is stored the moment it is turned on. A flag that takes a value only opens its
    /// field — it is stored once something is typed, so an unfinished row can never reach the
    /// command line.
    private func setEnabled(_ enabled: Bool, for flag: ScrcpyFlag) {
        var values = preferences.advancedFlagValues
        if enabled {
            if flag.takesValue {
                awaitingValue.insert(flag.name)
            } else {
                values[flag.name] = ""
            }
        } else {
            awaitingValue.remove(flag.name)
            values.removeValue(forKey: flag.name)
        }
        preferences.advancedFlagValues = values
    }
}
