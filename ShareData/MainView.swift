//
//  MainView.swift
//  ShareData
//
//  Created by Saša Mitrović on 03.10.20.
//

import SwiftUI

struct MainView: View {
    var body: some View {
        NavigationView {
            VStack {
                let book = Data()
                BookList().environmentObject(book)
                
                NavigationLink(
                    destination: /*@START_MENU_TOKEN@*/Text("Destination")/*@END_MENU_TOKEN@*/,
                    label: {
                        /*@START_MENU_TOKEN@*/Text("Navigate")/*@END_MENU_TOKEN@*/
                    })
            }
            
        }
    }
}

struct MainView_Previews: PreviewProvider {
    static var previews: some View {
        MainView()
    }
}
