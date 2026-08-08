import Foundation
import StoreKit
import SwiftData

/// StoreKit 2 wrapper for one-time in-app purchases (the vertical packs). No
/// subscriptions — every product is non-consumable and owned forever once bought.
@MainActor
@Observable
final class StoreManager {
    private(set) var products: [Product] = []
    private(set) var purchasedIDs: Set<String> = []
    private(set) var isLoading = false
    var lastError: String?

    private var updatesTask: Task<Void, Never>?

    /// Call once at launch: load products and begin listening for entitlements.
    /// StoreManager is app-scoped and lives for the whole session, so the
    /// transaction-listener task is intentionally long-lived.
    func start() async {
        if updatesTask == nil { updatesTask = listenForTransactions() }
        await loadProducts()
        await refreshEntitlements()
    }

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let loaded = try await Product.products(for: VerticalPacks.productIDs)
            products = loaded.sorted { $0.displayName < $1.displayName }
        } catch {
            lastError = "Couldn't load the store: \(error.localizedDescription)"
        }
    }

    func product(for id: String) -> Product? { products.first { $0.id == id } }

    func isPurchased(_ id: String) -> Bool { purchasedIDs.contains(id) }

    /// Buy a pack. On success, its templates are seeded into the local store.
    func purchase(_ product: Product, into context: ModelContext) async {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                purchasedIDs.insert(transaction.productID)
                seedTemplates(for: transaction.productID, into: context)
                await transaction.finish()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            lastError = "Purchase failed: \(error.localizedDescription)"
        }
    }

    /// Re-sync entitlements from the App Store (Settings ▸ Restore Purchases).
    func restore(into context: ModelContext) async {
        try? await AppStore.sync()
        await refreshEntitlements()
        for id in purchasedIDs { seedTemplates(for: id, into: context) }
    }

    // MARK: - Entitlements

    private func refreshEntitlements() async {
        var owned: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if let transaction = try? checkVerified(result) {
                owned.insert(transaction.productID)
            }
        }
        purchasedIDs = owned
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await update in Transaction.updates {
                guard let self else { continue }
                if let transaction = try? self.checkVerified(update) {
                    await MainActor.run { _ = self.purchasedIDs.insert(transaction.productID) }
                    await transaction.finish()
                }
            }
        }
    }

    private nonisolated func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe): return safe
        case .unverified: throw StoreError.failedVerification
        }
    }

    // MARK: - Seeding pack templates

    /// Insert a pack's templates into the store, skipping any already present.
    func seedTemplates(for productID: String, into context: ModelContext) {
        guard let pack = VerticalPacks.pack(for: productID) else { return }
        let existing = (try? context.fetch(FetchDescriptor<SummaryTemplate>())) ?? []
        let existingNames = Set(existing.map(\.name))
        var baseSort = (existing.map(\.sortIndex).max() ?? 0) + 1
        var inserted = false
        for template in pack.templates where !existingNames.contains(template.name) {
            context.insert(SummaryTemplate(
                name: template.name,
                symbol: template.symbol,
                instructions: template.instructions,
                isBuiltIn: false,
                sortIndex: baseSort,
                packID: productID
            ))
            baseSort += 1
            inserted = true
        }
        if inserted { try? context.save() }
    }

    enum StoreError: Error { case failedVerification }
}
