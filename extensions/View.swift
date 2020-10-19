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
    
}
