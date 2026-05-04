import ObserverCore
import SwiftUI

struct SuggestionsView: View {
    @EnvironmentObject var model: DashboardModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Suggested Workflows")
                    .font(.largeTitle.bold())
                Spacer()
                Button {
                    Task { await model.runAnalysis() }
                } label: {
                    if case .running = model.analysisState {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text("Analyzing…")
                        }
                    } else {
                        Label("Run analysis", systemImage: "wand.and.stars")
                    }
                }
                .disabled(isRunning)
                .help("Cluster the last 7 days, label sessions with Haiku 4.5, and ask Opus 4.7 for workflow suggestions.")
            }

            statusBanner

            if model.suggestions.isEmpty {
                ContentUnavailableView(
                    "No suggestions yet",
                    systemImage: "lightbulb",
                    description: Text("Click \"Run analysis\" to scan your last 7 days of captures.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(model.suggestions, id: \.id) { suggestion in
                            SuggestionCard(
                                suggestion: suggestion,
                                onDismiss: { model.dismissSuggestion(suggestion) },
                                onSave: { model.saveSuggestionAsWorkflow(suggestion) }
                            )
                        }
                    }
                }
            }
        }
        .padding()
    }

    private var isRunning: Bool {
        if case .running = model.analysisState { return true } else { return false }
    }

    @ViewBuilder
    private var statusBanner: some View {
        switch model.analysisState {
        case .idle:
            EmptyView()
        case .running(let msg):
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text(msg).font(.callout)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.blue.opacity(0.10))
            .cornerRadius(6)
        case .completed(let msg):
            Label(msg, systemImage: "checkmark.circle.fill")
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.green.opacity(0.12))
                .cornerRadius(6)
        case .failed(let msg):
            Label(msg, systemImage: "exclamationmark.triangle.fill")
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.red.opacity(0.12))
                .cornerRadius(6)
        }
    }
}

private struct SuggestionCard: View {
    let suggestion: WorkflowSuggestion
    let onDismiss: () -> Void
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(suggestion.title).font(.headline)
                Spacer()
                Text(String(format: "%.0f%% confidence", suggestion.confidence * 100))
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.blue.opacity(0.15))
                    .cornerRadius(4)
            }
            Text(suggestion.description)
                .font(.body)
                .foregroundStyle(.secondary)
            HStack {
                if let trigger = suggestion.triggerPattern {
                    Label(trigger, systemImage: "bolt")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if suggestion.estimatedTimeSavedMin > 0 {
                    Label("~\(suggestion.estimatedTimeSavedMin) min/occurrence", systemImage: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            HStack {
                Spacer()
                Button("Dismiss", role: .destructive, action: onDismiss)
                Button("Save as workflow", action: onSave)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(.gray.opacity(0.08))
        .cornerRadius(10)
    }
}
