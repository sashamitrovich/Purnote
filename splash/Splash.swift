//
//  Splash.swift
//  purenote
//
//  Created by Saša Mitrović on 20.10.20.
//

import SwiftUI

struct Splash: View {
    @Binding var shownSplashScreen : Bool
    var iCloudConnectionNotAvailable : Bool
    
    
    @ViewBuilder
    var body: some View {
       
         
            VStack(alignment: .center) {
                    
//                Spacer()
                SplashSummary().padding(.bottom, 30.0)
//                Spacer()
                
                if !iCloudConnectionNotAvailable {
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
                else if iCloudConnectionNotAvailable {
                    VStack(alignment: .center) {
                        Text("No iCloud Drive access")
                            .font(.title2)
                            .foregroundColor(.orange)
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 20.0)
                        Text("To use Purenote please enable iCloud in your phone Settings and grant Purenote access to the iCloud Drive")
                            .multilineTextAlignment(.center)
                            .frame(width:300)                        
                    }
             
                }

            }
            
    }
}

struct Splash_Previews: PreviewProvider {
    static var previews: some View {
        Splash(shownSplashScreen: .constant(false), iCloudConnectionNotAvailable: true)
    }
}
