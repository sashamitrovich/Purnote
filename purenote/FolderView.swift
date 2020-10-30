//
//  FolderView.swift
//  purenote
//
//  Created by Saša Mitrović on 15.10.20.
//

import SwiftUI
import UIKit
import Introspect

struct FolderView: View {
    @EnvironmentObject var data: DataManager
    @State private var selectedUrl: URL?
    @State var showingFolderEdit = false
    @State var shouldAlertForFolderDelete = false
    
    @State var folderIndexToHandle  = Int.max
    
    @ViewBuilder
    var body: some View {
        
        ForEach(data.folders.indices) { index in
            //                HStack {
            
            if !(showingFolderEdit && folderIndexToHandle == index) {
                NavigationLink(destination: MenuView().environmentObject(DataManager(url: data.folders[index].url)),
                               tag: data.folders[index].url, selection: self.customBinding()) {
                    
                    HStack {
                        Image(systemName: "folder")
                            // my own modest Image extension
                            // inspired by
                            // https://stackoverflow.com/a/59974025/1393362
                            .systemOrange()
                        Text(data.folders[index].id)
                            .fontWeight(.semibold)
                            .font(.title3)
                            .foregroundColor(Color(UIColor.label))
                    }
                    
                    .contextMenu {
                        Button(action: {
                            showingFolderEdit.toggle()
                            folderIndexToHandle = index
                        }) {
                            Text("Rename Folder")
                            Image(systemName: "pencil")
                        }
                        
                        
                        Button(action: {
                            shouldAlertForFolderDelete.toggle()
                            folderIndexToHandle = index
                        }) {
                            Text("Delete Folder")
                            Image(systemName: "trash")
                        }
                    }
                    
                    
                    
                    
                }
                .alert(isPresented: $shouldAlertForFolderDelete) {Alert(title: Text("Are you sure you want to delete \(data.folders[folderIndexToHandle].id) and it's contents?"), message: Text("There is no undo"), primaryButton: .destructive(Text("Delete")) {
                    deleteFolder(id: data.folders[folderIndexToHandle].id)
                    
                }, secondaryButton: .cancel())
                }
                .showIf(condition: !(folderIndexToHandle == index && !showingFolderEdit))
            }
            
            if showingFolderEdit && folderIndexToHandle == index {
                HStack {
                    TextField(data.folders[folderIndexToHandle].id, text: $data.folders[folderIndexToHandle].id, onCommit: {

                        renameFolder(index: index)
                        folderIndexToHandle = Int.max
                        showingFolderEdit = false
                        
                    }
                    )
                    .font(.title3)
                    .introspectTextField() { tF in
                        tF.becomeFirstResponder()
                    }
                    Spacer()
                    Button(action:{
                        showingFolderEdit.toggle()
                        folderIndexToHandle = Int.max
                    }) {
                    Image(systemName: "xmark.circle")
                        .foregroundColor(.red)
                    }
                }
            }
            
        }
        .listStyle(PlainListStyle())
        
        if data.folders.count == 0 {
            VStack {
                HStack {
                    Text("Tap the")
                    Image(systemName: "folder.badge.plus")
                    Text("button to create a new folder")
                }.placeholderForegroundColor()
            }
        }
        
                  
        
        
    }
    
    func renameFolder(index: Int) {
        
        let oldUrl = data.folders[index].url
        let newUrl = data.folders[index].url.deletingLastPathComponent().appendingPathComponent(data.folders[index].id)
        
        
        do {
            try FileManager.default.moveItem(at: oldUrl, to: newUrl)
            
            
        }
        catch {
            // failed
            print("Failed to rename directory: \(error).")
        }

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

//struct FolderView_Previews: PreviewProvider {
//    static var previews: some View {
//        FolderView().environmentObject(DataManager.sampleDataManager())
//    }
//}
