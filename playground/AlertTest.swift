//
//  AlertTest.swift
//  Purnote
//
//  Created by Saša Mitrović on 27.10.20.
//

import SwiftUI

struct AlertTest: View {
    @State var displayAlert = false
    var body: some View {
        Text(/*@START_MENU_TOKEN@*/"Hello, World!"/*@END_MENU_TOKEN@*/)
            .onTapGesture(perform: {
                displayAlert.toggle()
            })
            .alert(isPresented: $displayAlert) {
                
                Alert(title: Text("Can't create folder"), message: Text("Please enter folder name"), dismissButton: .default(Text("Got it!")))
            }
    }
}

struct AlertTest_Previews: PreviewProvider {
    static var previews: some View {
        AlertTest()
    }
}
