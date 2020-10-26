//
//  Form.swift
//  Purnote
//
//  Created by Saša Mitrović on 26.10.20.
//

import SwiftUI

struct Form: View {
    @State private var showPopover: Bool = true
    


   @State var text:String = ""
    
    var body: some View {
//        TextField("Enter some text", text: $text)
        VStack {
            Button("Show popover") {
                self.showPopover = true
            }.popover(
                isPresented: self.$showPopover,
                arrowEdge: .bottom
            ) { Text("Popover") }
        }
    }
}

struct Form_Previews: PreviewProvider {
    static var previews: some View {
        Form()
    }
}
