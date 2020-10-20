//
//  NoteView.swift
//  purenote
//
//  Created by Saša Mitrović on 15.10.20.
//

import SwiftUI
import Parma

struct NoteView: View {
    @EnvironmentObject var data: DataManager
    @State private var isEditing = false
    
    var body: some View {
                
        ForEach(data.notes) { note in
            
//            conditionalView(note: note)
            VStack {
               
                    NavigationLink(destination:
                                    ScrollView {
                                        Parma(note.content, render: MyRender())
                                        .frame(maxWidth: .infinity, alignment: .topLeading)
                                        .padding(.leading, 5.0)
                                        .navigationBarItems(trailing:  Button(action: {isEditing = true}) {
                                            Image(systemName: "pencil").font(.title2)
                                            
                                        }.sheet(isPresented: $isEditing) {
                                            
                                            NoteEdit(isEditing: $isEditing, note: note)
                                                .environmentObject(data)
                                            
                                        })
                                        //                                        .frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 5.0)
                                            .environmentObject(self.data)
                                    }) {
                        ListRow(note: note).environmentObject(self.data)
                    }.showIf(condition: note.isLocal)
               
                
                ICloudItemView(note : note).environmentObject(self.data)
                    .frame(maxWidth: .infinity, alignment: .leading).showIf(condition: !note.isLocal)
            }
            
        }.onDelete(perform: deleteItems).padding(.leading, 5.0)
        
        VStack {
            HStack {
                Text("Tap the")
                Image(systemName: "square.and.pencil")
                Text("button to create a new note")
            }
        }.showIf(condition: data.notes.count == 0)
    }
    
    // how to return HStack or VStack as a view
    // https://stackoverflow.com/a/59663108/1393362
    func conditionalView(note: Note) -> AnyView {
        if note.isLocal  {
            
            return AnyView( LazyVStack {
                

                //                        .frame(alignment: .leading)
            }.frame(maxWidth: .infinity, alignment: .leading))
        }
        else {
            return AnyView(ICloudItemView(note : note).environmentObject(self.data)
                            .frame(maxWidth: .infinity, alignment: .leading))
        }
    }
    
    func readView(note: Note) -> some View {
        return ScrollView{
            Parma(note.content, render: MyRender())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 5.0)
                .navigationBarItems(trailing:  Button(action: {isEditing = true}) {
                    Image(systemName: "pencil").font(.title2)
                    
                }.sheet(isPresented: $isEditing) {
                    
                    NewFolderView(showSheetView: $isEditing, url: data.getCurrentUrl())
                        .environmentObject(data)
                    
                })
        }
    }
    
    
    func deleteItems(at offsets: IndexSet) {
        
        for offset in offsets.enumerated() {
            do {
                try FileManager.default.trashItem(at: data.notes[offset.element].url, resultingItemURL: nil)
            }
            catch {
                // failed
                print("Failed to delete notes: \(error).")
            }
            
        }
        data.notes.remove(atOffsets: offsets)
        
    }
}

struct NoteView_Previews: PreviewProvider {
    static var previews: some View {
        NoteView().environmentObject(DataManager())
    }
}

struct MyRender: ParmaRenderable {
    
    public func  paragraphBlock(view: AnyView) -> AnyView {
        return AnyView(
            VStack(alignment: .leading) {
                view
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            })
        
        
    }
    
    //    func heading(level: HeadingLevel?, textView: Text) -> Text {
    //        switch level {
    //        case .one:
    //            return textView.font(.system(.largeTitle, design: .serif)).bold()
    //        case .two:
    //            return textView.font(.system(.title, design: .serif)).bold()
    //        case .three:
    //            return textView.font(.system(.title2)).bold()
    //        default:
    //            return textView.font(.system(.title3)).bold()
    //        }
    //    }
    
    func headingBlock(level: HeadingLevel?, view: AnyView) -> AnyView {
        switch level {
        case .one, .two:
            return AnyView(
                VStack(alignment: .leading, spacing: 2) {
                    view
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                }
            )
        default:
            return AnyView(view.padding(.bottom, 4)
                            .frame(maxWidth: .infinity, alignment: .leading)
            )
        }
    }
    
    
    
    //    func listItem(view: AnyView) -> AnyView {
    //        let bullet = "•"
    //        return AnyView(
    //            VStack(alignment: .leading) {
    //                HStack(alignment: .top, spacing: 8) {
    //                    Text(bullet).frame(alignment: .leading)
    //                    view
    //                        .frame(maxWidth: .infinity, alignment: .leading)
    //                        .fixedSize(horizontal: false, vertical: true)
    //                }
    //                .padding(.leading, 4)
    //            }
    //        )
    //    }
}
