//
//  Splash.swift
//  purenote
//
//  Created by Saša Mitrović on 20.10.20.
//

import SwiftUI

struct Splash: View {
    @Binding var shownSplashScreen : Bool
    
    var body: some View {
       
         
            VStack(alignment: .center) {
                    
                Spacer()
                    SplashSummary()
                Spacer()
                    Button(action: {
                        shownSplashScreen.toggle()
                    })
                    {
                        Text("Continue").font(.title2)
                            .foregroundColor(Color.white)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 2.0).padding(.horizontal, 58.0)
                            .background(Color(UIColor.systemOrange))
                            .cornerRadius(7)
                    }
                    .padding()
            }
            
    }
}

struct Splash_Previews: PreviewProvider {
    static var previews: some View {
        Splash(shownSplashScreen: .constant(false))
    }
}
