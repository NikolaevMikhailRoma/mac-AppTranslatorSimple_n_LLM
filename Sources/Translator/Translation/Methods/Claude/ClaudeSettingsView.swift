import SwiftUI
import TranslatorCore

struct ClaudeSettingsView: View {
    @Binding var settings: ClaudeSettings
    /// From General, to show what the prompt's placeholder becomes.
    let language1: String
    let language2: String

    /// What Claude Code said about itself; nil until asked, or when it could not be asked.
    @State private var info: ClaudeCodeInfo?
    /// Why Claude Code cannot translate: not found, not signed in, does not start.
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
            Text("Your Claude plan through Claude Code on this Mac, no API key. The text goes to Anthropic and counts toward the plan's usage limits.")
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
            if let problem {
                setup(problem)
            } else {
                ready
            }
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

    /// Model, effort and prompt, once Claude Code is there and signed in (or still being asked).
    @ViewBuilder
    private var ready: some View {
        Text(statusLine)
            .font(.caption)
            .foregroundStyle(.secondary)

        FormRow(label: "Model") {
            Picker("", selection: $settings.model) {
                if chosenModel == nil {
                    Text(info == nil ? settings.model : "\(settings.model) (not listed)").tag(settings.model)
                }
                ForEach(info?.models ?? []) { model in Text(model.displayName).tag(model.value) }
            }
            .labelsHidden()
            .frame(width: 230)
            .help(chosenModel?.description ?? "")
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

    private var statusLine: String {
        guard let info, !asking else { return "Asking Claude Code…" }
        return ["Claude Code \(info.version ?? "")", "signed in", info.subscription].compactMap { $0 }
            .joined(separator: " · ")
    }

    /// What is wrong and the steps to fix it, in place of the settings that cannot work yet.
    private func setup(_ problem: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(problem)
                .foregroundStyle(.red)
            Text("Set up once, in Terminal:")
                .padding(.top, 6)
            Text("1. Install Claude Code:")
            Text("curl -fsSL https://claude.ai/install.sh | bash")
                .font(.system(.body, design: .monospaced))
                .padding(.leading, 16)
            Text("or with Homebrew:")
                .padding(.leading, 16)
            Text("brew install --cask claude-code")
                .font(.system(.body, design: .monospaced))
                .padding(.leading, 16)
            Text("2. Run claude and sign in with your Claude account in the browser it opens.")
            Text("3. Come back here and press ↻.")
        }
        .textSelection(.enabled)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.top, 6)
    }

    private func askClaudeCode() async {
        let path = settings.executable.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let claude = found else {
            info = nil
            problem = path.isEmpty ? "Claude Code is not installed: no claude in ~/.local/bin, /opt/homebrew/bin or /usr/local/bin."
                                   : "No Claude Code at \(path)."
            return
        }
        asking = true
        defer { asking = false }
        do {
            let info = try await claude.info()
            self.info = info
            problem = info.signedIn ? nil : "Claude Code is not signed in."
        } catch is CancellationError {
        } catch {
            info = nil
            problem = error.localizedDescription
        }
    }
}
