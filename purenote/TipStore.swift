//
//  TipStore.swift
//  purenote
//

import StoreKit
import SwiftUI

/// The tip jar: loads the support products and handles purchases.
///
/// Tips are consumable — a user can leave more than one. The product IDs here
/// must match the consumable In-App Purchases you create in App Store Connect;
/// the display name and price come from there (or from the .storekit file when
/// testing in Xcode).
@MainActor
final class TipStore: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published private(set) var isPurchasing = false
    @Published var thankedProductID: String?

    static let productIDs = [
        "com.mitrovic.purenote.tip.small",
        "com.mitrovic.purenote.tip.medium",
        "com.mitrovic.purenote.tip.large",
    ]

    init() {
        // Finish any interrupted purchases that surface later (e.g. a purchase
        // that completed while the app was backgrounded).
        Task { await listenForTransactions() }
    }

    func loadProducts() async {
        do {
            products = try await Product.products(for: Self.productIDs)
                .sorted { $0.price < $1.price }
        } catch {
            print("Failed to load tip products: \(error)")
        }
    }

    func purchase(_ product: Product) async {
        guard !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    thankedProductID = product.id
                }
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            print("Tip purchase failed: \(error)")
        }
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            if case .verified(let transaction) = result {
                await transaction.finish()
            }
        }
    }
}
