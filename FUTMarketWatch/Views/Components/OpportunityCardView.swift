import SwiftUI

/// Carte détaillant une opportunité : joueur, prix cible, revente estimée, bénéfice net et risque.
struct OpportunityCardView: View {
    let alert: MarketAlert

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(alert.type.rawValue, systemImage: alert.type.systemImage)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                RiskBadge(level: alert.riskLevel)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(alert.player.name)
                    .font(.headline)
                Text("\(alert.player.club) · \(alert.player.overall) OVR · \(alert.player.rarity.rawValue)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                priceColumn(title: "Achat", value: alert.buyPrice.coinsFormatted, tint: .primary)
                priceColumn(title: "Revente est.", value: alert.estimatedSellPrice.coinsFormatted, tint: .primary)
                priceColumn(
                    title: "Bénéfice net",
                    value: (alert.netProfit >= 0 ? "+" : "") + alert.netProfit.coinsFormatted,
                    tint: alert.netProfit >= 0 ? .green : .red
                )
            }

            Text(alert.rationale)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func priceColumn(title: String, value: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    OpportunityCardView(alert: MarketAlert(
        id: UUID(),
        player: MockData.players[0],
        type: .snipe,
        detectedAt: .now,
        buyPrice: 2_400_000,
        estimatedSellPrice: 2_950_000,
        riskLevel: .medium,
        rationale: "19% sous la moyenne du marché sur 24h"
    ))
    .padding()
}
