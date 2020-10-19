//
//  FolderView.swift
//  purenote
//
//  Created by Saša Mitrović on 15.10.20.
//

import SwiftUI

struct FolderView: View {
    @EnvironmentObject var data: DataManager
    @State private var selectedUrl: URL?
    
    var body: some View {
        
    
            ForEach(data.folders) { folder in
                
                HStack {
                    NavigationLink(destination: MenuView(data: DataManager(url: folder.url)).environmentObject(self.data),
                                   tag: folder.url, selection: self.customBinding()) {
                        
                        HStack {
                            Image(systemName: "folder")
                            Text(folder.id)
                                .fontWeight(.semibold)
                                .font(.title3)
                        }
                    }
                }
        }
//            .listRowBackground(Color.red)
    }
    
    func customBinding() -> Binding<URL?> {
        let binding = Binding<URL?>(get: {
            self.selectedUrl
        }, set: {
            print("Folder with URL \(String(describing: $0)) chosen")
            self.selectedUrl = $0            
        })
        return binding
    }
}

struct FolderView_Previews: PreviewProvider {
    static var previews: some View {
        FolderView().environmentObject(DataManager())
    }
}
