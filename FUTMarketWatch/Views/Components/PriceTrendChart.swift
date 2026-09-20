import SwiftUI
import Charts

/// Trace la courbe de prix d'une carte pour visualiser points bas et pics de revente.
struct PriceTrendChart: View {
    let history: [PricePoint]

    var body: some View {
        Chart(history) { point in
            LineMark(
                x: .value("Heure", point.timestamp),
                y: .value("Prix", point.price)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(Color.accentColor)

            AreaMark(
                x: .value("Heure", point.timestamp),
                y: .value("Prix", point.price)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(Color.accentColor.opacity(0.12))
        }
        .chartXAxis(.hidden)
        .frame(height: 80)
    }
}

#Preview {
    PriceTrendChart(history: MockData.generatePriceHistory(around: 250_000))
        .padding()
}
