import SwiftUI

/// Petite tuile de statistique réutilisée dans le dashboard et le portefeuille.
struct StatTile: View {
    let title: String
    let value: String
    var tint: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

#Preview {
    HStack {
        StatTile(title: "Cartes suivies", value: "128")
        StatTile(title: "Bénéfice net", value: "+42 500", tint: .green)
    }
    .padding()
}
