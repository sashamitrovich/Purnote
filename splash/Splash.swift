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
                    
                SplashSummary()
//                    .padding(.bottom, 30.0)
                
                if !iCloudConnectionNotAvailable {
                    Button(action: {
                        shownSplashScreen.toggle()
                    })
                    {
                        Text("OK").font(.title2)
                            .foregroundColor(Color.white)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 10.0).padding(.horizontal, 78.0)
                            .background(Color(UIColor.systemOrange))
                            .cornerRadius(7)
                    }
                    .padding()
                }                
                else if iCloudConnectionNotAvailable {
                    VStack(alignment: .center) {
                        HStack(alignment: .center) {
                            Image(systemName: "xmark.octagon.fill")
                                .font(.largeTitle)
                                .foregroundColor(Color(UIColor.red))
                                .accessibility(hidden: true)
                                .foregroundColor(.red)
                            Text("Purnote can't access the iCloud Drive")
                                .font(.headline)
                                .multilineTextAlignment(.center)
                        }.frame(width: 220)
                        .padding()
                        
                        Text("Please activate your iCloud Drive and grant Purnote access to the iCloud Drive")
                            .font(.callout)
                            .multilineTextAlignment(.center)
                            .frame(width:300)
                            .padding()
                        
                        Button(action: {
                            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                        }) {
                            Text("Open Settings").font(.title3)
                                .foregroundColor(Color.white)
                                .multilineTextAlignment(.center)
                                .padding(.vertical, 7.0).padding(.horizontal, 28.0)
                                .background(Color(UIColor.systemGray))
                                .cornerRadius(7)
                        }
       
                            
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
