//
//  NavView.swift
//  purenote
//
//  Created by Saša Mitrović on 19.10.20.
//

import SwiftUI

struct NavView: View {
    var body: some View {
        NavigationView {
            NavLinksView()
        
        }

    }
}

struct NavView_Previews: PreviewProvider {
    static var previews: some View {
        NavView()
    }
}
