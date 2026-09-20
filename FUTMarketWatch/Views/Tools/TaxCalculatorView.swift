import SwiftUI

/// Outil intégré pour calculer rapidement la taxe de 5% et la rentabilité d'une carte.
struct TaxCalculatorView: View {
    @State private var buyPriceText: String = ""
    @State private var sellPriceText: String = ""
    @State private var taxRatePercent: Double = 5

    private var result: TaxCalculator.Result? {
        guard let buy = Int(buyPriceText), let sell = Int(sellPriceText), buy > 0, sell > 0 else { return nil }
        return TaxCalculator.evaluate(buyPrice: buy, sellPrice: sell, taxRate: taxRatePercent / 100)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Prix") {
                    LabeledContent("Prix d'achat") {
                        TextField("0", text: $buyPriceText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Prix de revente visé") {
                        TextField("0", text: $sellPriceText)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Taxe de l'hôtel des ventes") {
                    Stepper(value: $taxRatePercent, in: 0...10, step: 0.5) {
                        Text("Taux: \(taxRatePercent, specifier: "%.1f")%")
                    }
                }

                if let result {
                    Section("Résultat") {
                        LabeledContent("Taxe prélevée", value: result.taxAmount.coinsFormatted)
                        LabeledContent("Net perçu", value: result.netSellPrice.coinsFormatted)
                        LabeledContent("Bénéfice net") {
                            Text((result.netProfit >= 0 ? "+" : "") + result.netProfit.coinsFormatted)
                                .foregroundStyle(result.isProfitable ? .green : .red)
                        }
                        LabeledContent("Marge", value: result.marginPercent.signedPercentFormatted)
                        LabeledContent("Seuil de rentabilité", value: result.breakEvenSellPrice.coinsFormatted)
                    }
                }
            }
            .navigationTitle("Calculateur de taxe")
        }
    }
}

#Preview {
    TaxCalculatorView()
}
