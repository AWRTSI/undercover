import SwiftUI

/// Pastille colorée indiquant le niveau de risque d'une opportunité (Faible/Moyen/Élevé).
struct RiskBadge: View {
    let level: RiskLevel

    private var color: Color {
        switch level {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }

    var body: some View {
        Text(level.rawValue)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}

#Preview {
    HStack {
        RiskBadge(level: .low)
        RiskBadge(level: .medium)
        RiskBadge(level: .high)
    }
    .padding()
}
