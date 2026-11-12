//
//  View.swift
//  purenote
//
//  Created by Saša Mitrović on 19.10.20.
//

import SwiftUI

extension View {
    func showIf(condition: Bool) -> AnyView {
        if condition {
            return AnyView(self)
        }
        else {
            return AnyView(EmptyView())
        }
 
    }
    
    func placeholderForegroundColor() -> some View {
        return self
            .foregroundColor(Color(UIColor.placeholderText))
    }

    /// Restores the List-row look now that the menu renders in a LazyVStack:
    /// a little vertical breathing room plus a bottom separator line. The row
    /// is stretched to full width first, so the separator is the same length on
    /// every row (folder and note alike) instead of hugging its text; an
    /// explicit 1pt rectangle is used rather than `Divider`, which rendered
    /// vertically inside the folder row's HStack.
    func menuRowStyle() -> some View {
        return self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 7)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.pn.rule)
                    .frame(height: 1)
            }
    }
    
}
