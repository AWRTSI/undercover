import Foundation

extension Int {
    /// Formatte un montant en pièces avec séparateur de milliers, ex. 1 450 000.
    var coinsFormatted: String {
        NumberFormatter.coins.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

extension Double {
    /// Formatte un ratio (0.18) en pourcentage signé, ex. "+18%" ou "-15%".
    var signedPercentFormatted: String {
        let percent = Int((self * 100).rounded())
        return percent >= 0 ? "+\(percent)%" : "\(percent)%"
    }
}
