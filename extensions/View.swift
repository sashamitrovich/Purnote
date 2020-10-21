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
    
}
