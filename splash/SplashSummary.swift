//
//  SplashSummary.swift
//  purenote
//
//  Created by Saša Mitrović on 20.10.20.
//

import SwiftUI

struct SplashSummary: View {
    var body: some View {
        VStack(alignment: .leading) {
            VStack {
                Text("Purnote")
                    .font(.largeTitle)
                    .fontWeight(.heavy)
                    .foregroundColor(Color(UIColor.systemOrange))                    
            }
            .frame(maxWidth: .infinity, alignment:.center)
            .padding()
            
            
            VStack(alignment:.leading) {
                SplashDetail(title: "Folders", subTitle: "Keep your notes organized", image: Image(systemName: "folder"))
                SplashDetail(title: "iCloud", subTitle: "Access them anytime on any device", image: Image(systemName: "icloud"))
                SplashDetail(title: "Markdown", subTitle: "Beatifully presented", image: Image(systemName: "list.bullet"))
                    //.padding(.leading, 8.0)
            }.padding()
            
          
        }
        .padding(.horizontal)
    }
}

struct SplashSummary_Previews: PreviewProvider {
    static var previews: some View {
        SplashSummary()
    }
}
