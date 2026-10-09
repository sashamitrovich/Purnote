//
//  View.swift
//  purenote
//
//  Created by Saša Mitrović on 19.10.20.
//

import SwiftUI

extension UIColor {
    /// Purnote's page colour: a warm near-white "paper" in light mode and a
    /// warm near-black in dark. Replaces the grey grouped-list background so
    /// every screen reads like one clean sheet to write on.
    static let purnotePaper = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.090, green: 0.084, blue: 0.067, alpha: 1)   // ~#17150F
            : UIColor(red: 0.988, green: 0.980, blue: 0.965, alpha: 1)   // ~#FCFAF6
    }

    /// A warm second paper tone, one step darker than `purnotePaper`: the
    /// editor's formatting bar and code blocks sit on it rather than a cool
    /// system grey.
    static let purnotePaper2 = UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.149, green: 0.133, blue: 0.106, alpha: 1)   // #26221B
            : UIColor(red: 0.957, green: 0.937, blue: 0.902, alpha: 1)   // #F4EFE6
    }
}

extension Color {
    static let purnotePaper = Color(uiColor: .purnotePaper)
    static let purnotePaper2 = Color(uiColor: .purnotePaper2)
}

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
                    .fill(Color(UIColor.separator))
                    .frame(height: 1)
            }
    }
    
}
