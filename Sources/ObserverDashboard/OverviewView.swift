import Charts
import ObserverCore
import SwiftUI

struct OverviewView: View {
    @EnvironmentObject var model: DashboardModel

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private var totalMinutes: Double {
        Double(model.totalCaptures) * Config.captureIntervalSeconds / 60.0
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                if model.slices.isEmpty {
                    ContentUnavailableView(
                        "No activity captured yet",
                        systemImage: "moon.zzz",
                        description: Text("Start the observer daemon and check back.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 300)
                } else {
                    statsRow
                    chartSection
                    topListSection
                }
            }
            .padding()
        }
    }

    private var header: some View {
        HStack {
            Text("Overview")
                .font(.largeTitle.bold())
            Spacer()
            Picker("", selection: $model.range) {
                ForEach(TimeRange.allCases) { r in Text(r.rawValue).tag(r) }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)
            .onChange(of: model.range) { model.reload() }

            Button {
                model.reload()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .help("Reload")
        }
    }

    private var statsRow: some View {
        HStack(spacing: 16) {
            statCard(title: "Observed", value: formatMinutes(totalMinutes))
            statCard(title: "Captures", value: "\(model.totalCaptures)")
            statCard(title: "Activities", value: "\(model.slices.count)")
        }
    }

    private func statCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title2.bold())
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.gray.opacity(0.08))
        .cornerRadius(10)
    }

    private var chartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Where time goes").font(.headline)
            Chart(displaySlices()) { slice in
                SectorMark(
                    angle: .value("Captures", slice.captures),
                    innerRadius: .ratio(0.55),
                    angularInset: 1.5
                )
                .foregroundStyle(by: .value("Activity", slice.label))
                .cornerRadius(3)
            }
            .frame(height: 320)
            .chartLegend(position: .trailing, alignment: .top, spacing: 8)
        }
    }

    /// Cap the pie at 9 slices + an "Other" bucket so the chart stays readable.
    private func displaySlices() -> [ActivitySlice] {
        let topN = 9
        if model.slices.count <= topN { return model.slices }
        let head = Array(model.slices.prefix(topN))
        let tailCaptures = model.slices.dropFirst(topN).reduce(0) { $0 + $1.captures }
        let other = ActivitySlice(
            id: "__other__",
            label: "Other (\(model.slices.count - topN))",
            captures: tailCaptures,
            isURL: false
        )
        return head + [other]
    }

    private var topListSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Top activities").font(.headline)
            ForEach(Array(model.slices.prefix(15).enumerated()), id: \.element.id) { idx, slice in
                HStack {
                    Text("\(idx + 1).")
                        .frame(width: 28, alignment: .trailing)
                        .foregroundStyle(.secondary)
                    Image(systemName: slice.isURL ? "globe" : "app.dashed")
                        .foregroundStyle(.secondary)
                    Text(slice.label).lineLimit(1).truncationMode(.tail)
                    Spacer()
                    Text(formatMinutes(slice.minutes))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .padding(.vertical, 4)
                Divider()
            }
        }
    }

    private func formatMinutes(_ minutes: Double) -> String {
        if minutes < 60 {
            return String(format: "%.0f min", minutes)
        }
        let h = Int(minutes) / 60
        let m = Int(minutes) % 60
        return "\(h)h \(m)m"
    }
}
