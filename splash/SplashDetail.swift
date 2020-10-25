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
    var image = Image(systemName: "folder")
    
    var body: some View {
        HStack(alignment: .center) {
            image
                .font(.largeTitle)
                .foregroundColor(Color(UIColor.orange))
                .padding()
                .accessibility(hidden: true)
                .frame(width: 60)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .accessibility(addTraits: .isHeader)
                Text(subTitle)
                    .font(.body)
                    .foregroundColor(.secondary)
                    //.fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct SplashDetail_Previews: PreviewProvider {
    static var previews: some View {
        SplashDetail()
    }
}
