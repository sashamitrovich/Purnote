//
//  NewFolderView.swift
//  purenote
//
//  Created by Saša Mitrović on 19.10.20.
//

import SwiftUI

struct FolderEdit: View {
    @EnvironmentObject var data: DataManager
    
    @State var folderName: String
    @Binding var showSheetView: Bool
    @State var shouldAlertForEmptyFolderName = false
    var url:URL
    @State var newFolderName : String = ""
    @FocusState private var nameFieldFocused: Bool
    
    func renameFolder() {
        
        let oldUrl = url
        let newUrl = url.deletingLastPathComponent().appendingPathComponent(newFolderName)
        
        
        do {            
            try FileManager.default.moveItem(at: oldUrl, to: newUrl)
            
            
        }
        catch {
            // failed
            print("Failed to rename directory: \(error).")
        }
        
        // new name should appear in the list
        if let index = data.folders.firstIndex(where: { $0.id == folderName }) {
            data.folders[index].id = newFolderName
            data.folders[index].url = newUrl
        }
        self.showSheetView = false
    }
    
    
    var body: some View {
        
        NavigationStack {
            VStack(alignment: .center) {
                HStack(alignment: .center) {
                    //                    TextField("Enter new folder name", text: $newFolderName)
                    //                        .foregroundColor(Color(UIColor.label))
                    FolderEditName(newFolderName: $newFolderName)
                        
                        .focused($nameFieldFocused)
                        .onAppear { nameFieldFocused = true }
                        .ignoresSafeArea()
                        
                        .frame(maxWidth: .infinity,maxHeight: .infinity, alignment: .topLeading)
                        .padding(EdgeInsets(top: 25, leading: 5, bottom: 5, trailing: 5))
                        
                        .navigationTitle("Rename Folder")
                        .navigationBarTitleDisplayMode(.inline)
                        .navigationBarItems(trailing:
                                                
                                                HStack {
                                                    Button(action: {
                                                        self.showSheetView = false
                                                    }) {
                                                        Text("Cancel").bold()
                                                    }
                                                    
                                                    Spacer(minLength: 20)
                                                    
                                                    Button(action: {
                                                        if folderName != String("") {
                                                            renameFolder()
                                                        }
                                                        else {
                                                            shouldAlertForEmptyFolderName.toggle()
                                                        }
                                                    }) {
                                                        Text("Save").bold()
                                                    } 
                                                }
                                            
                        )
                    
                }
            }
        }
        
        .alert(isPresented: $shouldAlertForEmptyFolderName) {
            Alert(title: Text("Can't create folder"), message: Text("Please enter folder name"), dismissButton: .default(Text("Got it!")))
        }
        
        
    }
}

struct FolderEditView_Previews: PreviewProvider {
    static var previews: some View {
        FolderNew(folderName: "", showSheetView: .constant(true), url: URL(fileURLWithPath: "/new/path")).environmentObject(DataManager.sampleDataManager())
    }
}
