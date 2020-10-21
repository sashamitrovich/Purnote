//
//  Image.swift
//  purenote
//
//  Created by Saša Mitrović on 19.10.20.
//

import Foundation
import SwiftUI

extension Image {
     func systemOrange() -> some View {
        return self
            .renderingMode(.template)
            .foregroundColor(Color(UIColor.systemOrange))
    }
    
  
   
}
