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
    @State var shouldAlertForFolderDelete = false
    
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
                            shouldAlertForFolderDelete.toggle()
                        }) {
                            Text("Delete Folder")
                            Image(systemName: "trash")
                        }
                    }
                    
                    
                    
                }
                .alert(isPresented: $shouldAlertForFolderDelete) {Alert(title: Text("Are you sure you want to delete \(folder.id) and it's contents?"), message: Text("There is no undo"), primaryButton: .destructive(Text("Delete")) {
                    deleteFolder(id: folder.id)
                    
                }, secondaryButton: .cancel())
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
    
    func deleteFolder(id:String) {
        
        if let index = data.folders.firstIndex(where: { $0.id == id }) {
            
            do {
                try FileManager.default.removeItem(at: data.folders[index].url
                )
            }
            catch {
                // failed
                print("Failed to delete directory: \(error).")
            }
            
            data.folders.remove(at: index)

        }            
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
