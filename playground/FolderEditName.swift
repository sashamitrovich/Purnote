//
//  FolderEditName.swift
//  Purnote
//
//  Created by Saša Mitrović on 29.10.20.
//

import SwiftUI

struct FolderEditName: View {
    @Binding var newFolderName:String
    
    var body: some View {
        Color(UIColor.systemGray6)
            .ignoresSafeArea() // Ignore just for the color
            .overlay(
                VStack(spacing: 20) {
                    HStack {
                        Image(systemName: "folder")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .foregroundColor(.black).font(.largeTitle)
                    }
                    .frame(width: 100, height: 100, alignment: .center)
     
                        
                    TextField("Edit here", text: $newFolderName)
                        .background(Color.white)
                        .font(.title)
                        .frame(width: 300, alignment: .center)
                        .cornerRadius(5)
                        .padding()
                                                                    
                })
    }
}

struct FolderEditName_Previews: PreviewProvider {
    static var previews: some View {
        FolderEditName(newFolderName: .constant("new folder"))
    }
}
