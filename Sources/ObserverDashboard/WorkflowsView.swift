import ObserverCore
import SwiftUI

struct WorkflowsView: View {
    @EnvironmentObject var model: DashboardModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Workflows")
                .font(.largeTitle.bold())

            if model.workflows.isEmpty {
                ContentUnavailableView(
                    "No saved workflows",
                    systemImage: "gearshape.2",
                    description: Text("Accept a suggestion from the Suggestions tab to save it here.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(model.workflows, id: \.id) { workflow in
                    HStack {
                        Image(systemName: workflow.enabled ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(workflow.enabled ? .green : .secondary)
                        VStack(alignment: .leading) {
                            Text(workflow.name).font(.headline)
                            Text("Saved \(workflow.createdAt.formatted(.relative(presentation: .named)))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
    }
}
