import Foundation

/// Calcule la taxe de revente (5% par défaut, appliquée par le jeu sur toute vente à l'hôtel des ventes)
/// et la rentabilité d'une opération d'achat/revente.
enum TaxCalculator {
    static let defaultTaxRate: Double = 0.05

    struct Result {
        let buyPrice: Int
        let sellPrice: Int
        let taxRate: Double

        var taxAmount: Int { Int(Double(sellPrice) * taxRate) }
        var netSellPrice: Int { sellPrice - taxAmount }
        var netProfit: Int { netSellPrice - buyPrice }
        var marginPercent: Double {
            guard buyPrice > 0 else { return 0 }
            return Double(netProfit) / Double(buyPrice)
        }
        var isProfitable: Bool { netProfit > 0 }

        /// Prix de revente minimum à viser pour ne pas perdre d'argent après taxe.
        var breakEvenSellPrice: Int {
            Int(Double(buyPrice) / (1 - taxRate))
        }
    }

    static func evaluate(buyPrice: Int, sellPrice: Int, taxRate: Double = defaultTaxRate) -> Result {
        Result(buyPrice: buyPrice, sellPrice: sellPrice, taxRate: taxRate)
    }
}
