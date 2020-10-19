//
//  NavLinksView.swift
//  purenote
//
//  Created by Saša Mitrović on 19.10.20.
//

import SwiftUI

struct NavLinksView: View {
    private let names = ["Jorge", "Anfisa", "Pedro"]
    
    var body: some View {
        List(/*@START_MENU_TOKEN@*/0 ..< 5/*@END_MENU_TOKEN@*/) { item in
            NavigationLink(
                destination: /*@START_MENU_TOKEN@*/Text("Destination")/*@END_MENU_TOKEN@*/,
                label: {
                    /*@START_MENU_TOKEN@*/Text("Navigate")/*@END_MENU_TOKEN@*/
                })
        }
        .background(/*@START_MENU_TOKEN@*//*@PLACEHOLDER=View@*/Color.blue/*@END_MENU_TOKEN@*/)
        .navigationBarTitle(Text("title"), displayMode: .automatic)

        .padding(0.0)
        .navigationBarItems(trailing:
                                Button(action: {}) {
                                    Image(systemName: "plus.rectangle.on.folder").font(.title2)
                                    
                                }
                            /*
                                HStack {
                                    
                                    Button(action: {}) {
                                        Image(systemName: "plus.rectangle.on.folder").font(.title2)
                                        
                                    }
                                    Spacer(minLength: 15)
                                    
                                    NavigationLink(destination: Text("new destination:"), label: { Image(systemName: "square.and.pencil").font(.title2) }
                                    ).isDetailLink(true)
                                }
                                */
        ).frame(width: 450)
//        .background(Color.accentColor)
        
        
     
    }
}

struct NavLinksView_Previews: PreviewProvider {
    static var previews: some View {
        NavLinksView()
    }
}
