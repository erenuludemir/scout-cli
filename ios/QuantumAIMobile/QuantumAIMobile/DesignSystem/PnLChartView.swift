import SwiftUI
import Charts

public struct PnLData: Identifiable {
    public let id = UUID()
    public let time: Date
    public let value: Double
}

public struct PnLChartView: View {
    let data: [PnLData]

    private var chartTint: Color {
        data.last?.value ?? 0 >= 0 ? QAITheme.success : QAITheme.warning
    }

    private var isSimulatorBuild: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }

    private var minValue: Double? {
        data.map(\.value).min()
    }

    private var maxValue: Double? {
        data.map(\.value).max()
    }
    
    public var body: some View {
        VStack(alignment: .leading) {
            Text("CANLI PNL (USDT)").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundColor(.gray)

            if isSimulatorBuild {
                simulatorSummaryView
            } else if data.count >= 2 {
                Chart(data) {
                    LineMark(
                        x: .value("Zaman", $0.time),
                        y: .value("PnL", $0.value)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(chartTint)

                    AreaMark(
                        x: .value("Zaman", $0.time),
                        y: .value("PnL", $0.value)
                    )
                    .foregroundStyle(chartTint.opacity(0.18))
                }
                .chartYAxis(.hidden)
                .chartXAxis(.hidden)
                .frame(height: 60)
                .clipped()
            } else {
                Text("Grafik verisi bekleniyor")
                    .font(.caption2)
                    .foregroundStyle(QAITheme.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
            }
        }
        .padding()
        .background(QAITheme.cardBg)
        .cornerRadius(8)
    }

    private var simulatorSummaryView: some View {
        VStack(alignment: .leading, spacing: 6) {
            summaryRow("Son", value: data.last?.value)
            summaryRow("Min", value: minValue)
            summaryRow("Max", value: maxValue)
        }
        .frame(maxWidth: .infinity, minHeight: 60, alignment: .leading)
    }

    private func summaryRow(_ label: String, value: Double?) -> some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundStyle(QAITheme.textSecondary)
            Spacer()
            Text(formatted(value))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(QAITheme.textPrimary)
        }
    }

    private func formatted(_ value: Double?) -> String {
        guard let value else { return "--" }
        return value.formatted(.number.precision(.fractionLength(2)))
    }
}
