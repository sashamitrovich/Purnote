//
//  TipJarView.swift
//  purenote
//

import SwiftUI
import StoreKit

/// The support UI: a short line of context and one button per tip tier.
struct TipJarView: View {
    @StateObject private var store = TipStore()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Purnote is free, with no accounts and no ads. If it's useful to you, a tip helps keep it going.")
                .font(.footnote)
                .foregroundColor(.secondary)

            if store.products.isEmpty {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else {
                ForEach(store.products) { product in
                    Button {
                        Task { await store.purchase(product) }
                    } label: {
                        HStack {
                            Text(product.displayName)
                                .foregroundColor(.primary)
                            Spacer()
                            Text(product.displayPrice)
                                .fontWeight(.semibold)
                                .foregroundColor(Color(UIColor.systemOrange))
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color(UIColor.secondarySystemBackground),
                                    in: RoundedRectangle(cornerRadius: 10))
                    }
                    .disabled(store.isPurchasing)
                }
            }

            if let _ = store.thankedProductID {
                Label("Thank you — it genuinely helps.", systemImage: "heart.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(Color(UIColor.systemOrange))
            }
        }
        .task { await store.loadProducts() }
    }
}
