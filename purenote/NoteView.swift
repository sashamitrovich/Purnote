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
            if note.isLocal  {
                
                HStack {
                    
                    NavigationLink(destination:
                                    VStack {
                                        if self.isEditing {
                                            editView(note: note)
                                        }
                                        else {
                                            readView(note: note)
                                        }
                                    }.frame(maxWidth: .infinity, alignment: .leading).padding(.leading, 5.0)
                                    .environmentObject(self.data)) {
                        ListRow(note: note).environmentObject(self.data)
                    }.frame(alignment: .leading)
                }
            }
            else {
                ICloudItemView(note : note).environmentObject(self.data)
            }
        }.onDelete(perform: deleteItems).padding(.leading, 5.0)
        
    }
    
    func readView(note: Note) -> some View {
        return ScrollView{
                Parma(note.content, render: MyRender())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .navigationBarItems(trailing:  Button(action: {isEditing = true}) {
                    Image(systemName: "pencil").font(.title2)
                    
                })
           
        }
    }
    
    func editView(note: Note) -> some View {
        return  NoteEdit(note: note)
            .padding(.top)
            .navigationBarItems(trailing:  Button(action: {isEditing = false}) {
            Text("Done").font(.title2)
        })
    }


func deleteItems(at offsets: IndexSet) {
    
    for offset in offsets.enumerated() {
        do {
            try FileManager.default.trashItem(at: data.notes[offset.element].url, resultingItemURL: nil)
        }
        catch {
            // failed
            print("Unexpected error: \(error).")
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
            return AnyView(view.padding(.bottom, 4).frame(maxWidth: .infinity, alignment: .leading))
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
