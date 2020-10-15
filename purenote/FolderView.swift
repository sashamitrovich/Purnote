//
//  FolderView.swift
//  purenote
//
//  Created by Saša Mitrović on 15.10.20.
//

import SwiftUI

struct FolderView: View {
    @EnvironmentObject var data: DataManager
    
    var body: some View {
        ForEach(data.folders) { folder in
            Button(action: {                
                data.refresh(url: folder.url)
            }) {
                HStack {
                    if (folder.id == "..") {
                        Image(systemName: "arrowshape.turn.up.left")
                            .font(.title2)
                    }
                    else {
                        Image(systemName: "folder")
                            .font(.title2)
                    }
                    
                    Text(folder.id)
                        .fontWeight(.semibold)
                        .font(.title2)
                }
            }
        }
    }
}

struct FolderView_Previews: PreviewProvider {
    static var previews: some View {
        FolderView().environmentObject(DataManager())
    }
}
