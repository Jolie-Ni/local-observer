import ObserverAnalyzer
import ObserverCore
import SwiftUI

@main
struct DashboardApp: App {
    @StateObject private var model = DashboardModel()

    var body: some Scene {
        WindowGroup("Local Observer") {
            ContentView()
                .environmentObject(model)
                .frame(minWidth: 900, minHeight: 600)
        }
    }
}

enum AnalysisState: Equatable {
    case idle
    case running(message: String)
    case completed(message: String)
    case failed(String)
}

@MainActor
final class DashboardModel: ObservableObject {
    @Published var range: TimeRange = .today
    @Published var slices: [ActivitySlice] = []
    @Published var totalCaptures: Int = 0
    @Published var suggestions: [WorkflowSuggestion] = []
    @Published var workflows: [Workflow] = []
    @Published var loadError: String?
    @Published var analysisState: AnalysisState = .idle

    private let storage: Storage?
    private let stats: DashboardStats?

    init() {
        do {
            let storage = try Storage(path: Config.dbPath)
            self.storage = storage
            self.stats = DashboardStats(storage: storage)
        } catch {
            self.storage = nil
            self.stats = nil
            self.loadError = "Failed to open database: \(error.localizedDescription)"
        }
    }

    func reload() {
        guard let stats = stats else { return }
        let since = range.startDate
        do {
            slices = try stats.activitySlices(since: since)
            totalCaptures = try stats.totalCaptures(since: since)
            suggestions = try stats.suggestions()
            workflows = try stats.workflows()
            loadError = nil
        } catch {
            loadError = "Query failed: \(error.localizedDescription)"
        }
    }

    func runAnalysis() async {
        guard let storage = storage else {
            analysisState = .failed("Database not open.")
            return
        }
        guard let apiKey = AnthropicClient.keyFromEnvironment() else {
            analysisState = .failed(
                "ANTHROPIC_API_KEY is not set. Relaunch the dashboard from a shell where it's exported.")
            return
        }

        analysisState = .running(message: "Starting analysis…")
        let client = AnthropicClient(apiKey: apiKey)
        let runner = AnalysisRunner(storage: storage, client: client, lookbackDays: 7)

        do {
            let result = try await runner.run { [weak self] progress in
                Task { @MainActor in
                    self?.analysisState = .running(message: Self.describe(progress))
                }
            }
            let summary = "Analyzed \(result.sessionsAnalyzed) sessions • \(result.suggestionsCreated) suggestions"
            analysisState = .completed(message: summary)
            reload()
        } catch {
            analysisState = .failed(error.localizedDescription)
        }
    }

    func dismissSuggestion(_ suggestion: WorkflowSuggestion) {
        guard let storage = storage, let id = suggestion.id else { return }
        do {
            try storage.setSuggestionStatus(id: id, status: .dismissed)
            reload()
        } catch {
            loadError = "Couldn't dismiss: \(error.localizedDescription)"
        }
    }

    func saveSuggestionAsWorkflow(_ suggestion: WorkflowSuggestion) {
        guard let storage = storage else { return }
        do {
            try storage.saveSuggestionAsWorkflow(suggestion)
            reload()
        } catch {
            loadError = "Couldn't save: \(error.localizedDescription)"
        }
    }

    private static func describe(_ progress: AnalysisProgress) -> String {
        switch progress {
        case .clustering:
            return "Clustering captures into sessions…"
        case .labeling(let i, let total):
            return "Labeling sessions with Haiku 4.5 (\(i)/\(total))…"
        case .detecting:
            return "Detecting patterns with Opus 4.7…"
        case .persisting:
            return "Saving suggestions…"
        case .done:
            return "Done."
        }
    }
}

enum TimeRange: String, CaseIterable, Identifiable {
    case today = "Today"
    case last7 = "Last 7 days"
    case last30 = "Last 30 days"
    var id: String { rawValue }

    var startDate: Date {
        let cal = Calendar.current
        switch self {
        case .today:  return cal.startOfDay(for: Date())
        case .last7:  return cal.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        case .last30: return cal.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var model: DashboardModel

    var body: some View {
        TabView {
            OverviewView()
                .tabItem { Label("Overview", systemImage: "chart.pie") }

            WorkflowsView()
                .tabItem { Label("Workflows", systemImage: "gearshape.2") }

            SuggestionsView()
                .tabItem { Label("Suggestions", systemImage: "lightbulb") }
        }
        .padding()
        .onAppear { model.reload() }
        .overlay(alignment: .top) {
            if let err = model.loadError {
                Text(err)
                    .padding(8)
                    .background(.red.opacity(0.15))
                    .cornerRadius(6)
                    .padding()
            }
        }
    }
}
