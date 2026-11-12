//
//  Splash.swift
//  purenote
//
//  Created by Saša Mitrović on 20.10.20.
//

import SwiftUI

struct SplashDetail: View {
    var title = "Folders"
    var subTitle = "keep your notes organized"
    var imageName = "folder"
    
    var body: some View {
        HStack(alignment: .center) {
            Image(systemName: imageName)
                .font(.largeTitle)
                .foregroundColor(Color.pn.ribbon)
                .padding()
                .accessibility(hidden: true)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(Color.pn.ink)
                    .accessibility(addTraits: .isHeader)
                Text(subTitle)
                    .font(.body)
                    .foregroundColor(Color.pn.ink2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct Splash_Previews: PreviewProvider {
    static var previews: some View {
        SplashDetail()
    }
}
