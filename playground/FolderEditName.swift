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
        Color(.systemFill)
//            .ignoresSafeArea() // Ignore just for the color https://stackoverflow.com/questions/56437036/swiftui-how-do-i-change-the-background-color-of-a-view
            .overlay(
                VStack(spacing: 20) {
                    HStack {
                        Image(systemName: "folder")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .foregroundColor(.accentColor).font(.largeTitle)
                    }
                    .frame(width: 100, height: 100, alignment: .center)
     
                        
                    TextField("Folder name", text: $newFolderName)
                        .background(Color(.quaternarySystemFill))
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
                .environment(\.colorScheme, .dark)
            
            FolderEditName(newFolderName: .constant("new folder"))
                .environment(\.colorScheme, .light)
       

    }
}
