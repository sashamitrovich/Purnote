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
}

extension Color {
    static let purnotePaper = Color(uiColor: .purnotePaper)
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
    
}
