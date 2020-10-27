//
//  FolderView.swift
//  purenote
//
//  Created by Saša Mitrović on 15.10.20.
//

import SwiftUI
import UIKit


struct FolderView: View {
    @EnvironmentObject var data: DataManager
    @State private var selectedUrl: URL?
    @State var showingFolderEdit = false
    
    var body: some View {
        
        
        ForEach(data.folders) { folder in
            HStack {
                NavigationLink(destination: MenuView().environmentObject(DataManager(url: folder.url)),
                               tag: folder.url, selection: self.customBinding()) {
                    
                    HStack {
                        Image(systemName: "folder")
                            // my own modest Image extension
                            // inspired by
                            // https://stackoverflow.com/a/59974025/1393362
                            .systemOrange()
                        Text(folder.id)
                            .fontWeight(.semibold)
                            .font(.title3)
                            .foregroundColor(Color(UIColor.label))
                            
                            .sheet(isPresented: $showingFolderEdit) {
                                
                                FolderEdit(folderName: folder.id, showSheetView: $showingFolderEdit, url: folder.url, newFolderName: folder.id)
                                    .environmentObject(data)
//                                FolderEdit(folderName: folder.id, showSheetView: $showingFolderEdit, url: folder.url)
//                                    .onDisappear() {
//                                        data.refresh(url: data.getCurrentUrl())
//                                    }
//                                    .environmentObject(data)
                                    
                            }
                        
                        
                    }
                    
                    .contextMenu {
                        Button(action: {
                            showingFolderEdit.toggle()
                        }) {
                            Text("Rename Folder")
                            Image(systemName: "pencil")
                        }
                        
                        
                        Button(action: {
                            // enable geolocation
                        }) {
                            Text("Delete Folder")
                            Image(systemName: "trash")
                        }
                    }
                    
                    
                    
                }
                
                
            }
            
            
            
            
        }
        .listStyle(PlainListStyle())
        
        
        
        
        
        VStack {
            HStack {
                Text("Tap the")
                Image(systemName: "folder.badge.plus")
                Text("button to create a new folder")
            }.placeholderForegroundColor()
        }.showIf(condition: data.folders.count == 0)
    }
    
    
    
    func customBinding() -> Binding<URL?> {
        let binding = Binding<URL?>(get: {
            self.selectedUrl
        }, set: {
            self.selectedUrl = $0
        })
        return binding
    }
}

struct FolderView_Previews: PreviewProvider {
    static var previews: some View {
        FolderView().environmentObject(DataManager.sampleDataManager())
    }
}
