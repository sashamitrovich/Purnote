//
//  FolderRow.swift
//  ShareData
//
//  Created by Saša Mitrović on 12.10.20.
//

import SwiftUI


struct FolderRow: View {
    var folder: Folder
    var body: some View {
                
        HStack {
            Image(systemName: "folder")
            Text(folder.id)
           
        }.padding(.leading, 30.0).frame(width: 300.0, height: 70)
    }
}

struct FolderRow_Previews: PreviewProvider {
    static var previews: some View {
        
        let folder = Folder(id: "my folder", url: URL(fileURLWithPath: "/usr/my folder"))
        
        FolderRow(folder: folder)
    }
}
