import SwiftUI
import TranslatorCore

struct ClaudeSettingsView: View {
    @Binding var settings: ClaudeSettings
    /// From General, to show what the prompt's placeholder becomes.
    let language1: String
    let language2: String

    /// What Claude Code said about itself; nil until asked, or when it could not be asked.
    @State private var info: ClaudeCodeInfo?
    @State private var problem: String?
    @State private var asking = false

    private var found: ClaudeCode? { ClaudeCode.find(settings.executable) }

    private var chosenModel: ClaudeCodeInfo.Model? {
        info?.models.first { $0.value == settings.model }
    }

    /// The chosen model's levels; all of them until Claude Code has listed its models.
    private var effortLevels: [String] {
        guard let info else { return ClaudeSettings.effortLevels }
        return info.models.first { $0.value == settings.model }?.supportedEffortLevels ?? []
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Claude through your Claude subscription (Pro, Max, Team or Enterprise), by way of Claude Code on this Mac. No API key. The text goes to Anthropic; translations count toward the subscription's usage limits.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            FormRow(label: "Claude Code", help: "The claude command. Empty: looked up in ~/.local/bin, /opt/homebrew/bin and /usr/local/bin.") {
                TextField("", text: $settings.executable,
                          prompt: Text(found?.executable.path(percentEncoded: false) ?? "Not found"))
                    .frame(width: 230)
                Button {
                    Task { await askClaudeCode() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Ask Claude Code again: the account and the models")
            }
            status

            FormRow(label: "Model") {
                Picker("", selection: $settings.model) {
                    if chosenModel == nil {
                        Text(info == nil ? settings.model : "\(settings.model) (not listed)").tag(settings.model)
                    }
                    ForEach(info?.models ?? []) { model in Text(model.displayName).tag(model.value) }
                }
                .labelsHidden()
                .frame(width: 230)
            }
            if let description = chosenModel?.description {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            FormRow(label: "Effort", help: "How much Claude thinks before it answers. Default: Claude Code's choice for the model. Higher is slower and uses more of the limits; a translation seldom needs it.") {
                Picker("", selection: $settings.effort) {
                    Text("Default").tag("")
                    ForEach(effortLevels, id: \.self) { Text($0.capitalized).tag($0) }
                    if !settings.effort.isEmpty, !effortLevels.contains(settings.effort) {
                        Text("\(settings.effort.capitalized) (not for this model)").tag(settings.effort)
                    }
                }
                .labelsHidden()
                .frame(width: 230)
                .disabled(info != nil && effortLevels.isEmpty)
            }

            PromptEditor(prompt: $settings.prompt, language1: language1, language2: language2)
        }
        .task(id: settings.executable) {
            // Typing a path: ask once the typing stops.
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await askClaudeCode()
        }
        .onChange(of: settings.model) {
            if !settings.effort.isEmpty, !effortLevels.contains(settings.effort) { settings.effort = "" }
        }
    }

    @ViewBuilder
    private var status: some View {
        if asking {
            Text("Asking Claude Code…")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else if let info, info.signedIn {
            Text(["Claude Code \(info.version ?? "")", "signed in", info.subscription].compactMap { $0 }.joined(separator: " · "))
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text(info != nil ? ClaudeCodeError.notSignedIn.localizedDescription : problem ?? "")
                    .foregroundStyle(.red)
                Text("Set up once, in Terminal:")
                Text("1. Install Claude Code: curl -fsSL https://claude.ai/install.sh | bash\n    (or with Homebrew: brew install --cask claude-code)")
                Text("2. Run claude and sign in with your Claude account in the browser it opens.")
                Text("3. Come back here and press ↻.")
            }
            .font(.caption)
            .textSelection(.enabled)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func askClaudeCode() async {
        guard let claude = found else {
            info = nil
            problem = ClaudeCodeError.notFound(settings.executable.trimmingCharacters(in: .whitespacesAndNewlines))
                .localizedDescription
            return
        }
        asking = true
        defer { asking = false }
        do {
            info = try await claude.info()
            problem = nil
        } catch is CancellationError {
        } catch {
            info = nil
            problem = error.localizedDescription
        }
    }
}
