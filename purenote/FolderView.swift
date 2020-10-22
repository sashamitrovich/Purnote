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
    
    var body: some View {
        
        ScrollView {
            LazyVStack{
                ForEach(data.folders) { folder in
                    
                    VStack {
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
                                }.padding(.leading, 6.0).padding(.top, 6).padding(.bottom,6)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                
                                
                            }
                        }
                        .background(Color(UIColor.systemGray5), alignment: .leading)
                        .cornerRadius(5)
                        
                        Spacer(minLength: 6)
                    }
                }
            }
        }.showIf(condition: data.folders.count > 0)
        
        
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
