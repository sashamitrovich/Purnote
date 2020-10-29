//
//  EditView.swift
//  Purnote
//
//  Created by Saša Mitrović on 29.10.20.
//

import SwiftUI

struct EditView: View {
    @State var isEditMode: EditMode = .inactive
    
    var sampleData = ["Hello", "This is a row", "So is this"]
    
    var body: some View {
        NavigationView {
            List(sampleData, id: \.self) { rowValue in
                if (self.isEditMode == .active) {
                    Text("now is edit mode")
                } else  {
                    Text(rowValue)
                }
            }
            .navigationBarTitle(Text("Edit A Table?"), displayMode: .inline)
            .navigationBarItems(trailing: EditButton())
            .environment(\.editMode, self.$isEditMode)
        }
    }
}

struct EditView_Previews: PreviewProvider {
    static var previews: some View {
        EditView()
    }
}
