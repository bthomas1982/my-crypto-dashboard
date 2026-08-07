import SwiftUI
import StoreKit

/// The one-time-purchase pack store. Framed as "own it," never "subscribe."
struct PackStoreView: View {
    @Environment(StoreManager.self) private var store
    @Environment(\.modelContext) private var context

    var body: some View {
        List {
            Section {
                ForEach(VerticalPacks.all) { pack in
                    PackRow(pack: pack)
                }
            } footer: {
                Text("Each pack is a one-time purchase — buy it once, keep it forever. Packs add templates to your library; they don't change how recording or AI billing works.")
            }

            Section {
                Button("Restore purchases") {
                    Task { await store.restore(into: context) }
                }
            }
        }
        .navigationTitle("Template Packs")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if store.isLoading && store.products.isEmpty {
                ProgressView("Loading store…")
            }
        }
        .alert("Store error", isPresented: .constant(store.lastError != nil)) {
            Button("OK") { store.lastError = nil }
        } message: { Text(store.lastError ?? "") }
    }
}

private struct PackRow: View {
    let pack: VerticalPack
    @Environment(StoreManager.self) private var store
    @Environment(\.modelContext) private var context
    @State private var buying = false

    private var owned: Bool { store.isPurchased(pack.id) }
    private var product: Product? { store.product(for: pack.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: pack.symbol)
                    .font(.title2).foregroundStyle(Theme.coral).frame(width: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(pack.name).font(.headline)
                    Text(pack.tagline).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
            }

            HStack(spacing: 6) {
                ForEach(pack.templates, id: \.name) { t in
                    Text(t.name)
                        .font(Theme.mono(10))
                        .padding(.horizontal, 8).padding(.vertical, 4)
                        .background(Color(.tertiarySystemFill), in: Capsule())
                }
            }

            buyControl
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder private var buyControl: some View {
        if owned {
            Label("Owned", systemImage: "checkmark.seal.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.good)
        } else if let product {
            Button {
                buying = true
                Task { await store.purchase(product, into: context); buying = false }
            } label: {
                HStack {
                    if buying { ProgressView().tint(.white) }
                    Text(buying ? "…" : "Buy \(product.displayPrice)")
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Theme.coral, in: Capsule())
                .foregroundStyle(.white)
            }
            .disabled(buying)
        } else {
            Text("Unavailable")
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }
}
