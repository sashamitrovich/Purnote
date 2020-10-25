//
//  SplashTest.swift
//  Purnote
//
//  Created by Saša Mitrović on 25.10.20.
//

import SwiftUI

struct SplashTest: View {
    var body: some View {
        
        VStack (alignment: .leading)
        {
            Label("Some text", systemImage: "bolt.fill")
                
            Label("Some longer text", systemImage: "bolt.fill")
        }
//        .frame(alignment:.leading)
        
 
    }
}

struct SplashTest_Previews: PreviewProvider {
    static var previews: some View {
        SplashTest()
    }
}
