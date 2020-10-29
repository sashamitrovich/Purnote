//
//  NoteView.swift
//  Purnote
//
//  Created by Saša Mitrović on 29.10.20.
//

import SwiftUI
import Parma

struct NoteView: View {

 
    @EnvironmentObject var data: DataManager
    @EnvironmentObject var index: SearchIndex
    var note:Note
    @State var showEdit  = false
    @State var text = "some content to edit"

    
    var noteIndex: Int {
        data.notes.firstIndex(where: { $0.id == note.id })!
    }
    
    var body: some View {
        
        ScrollView {
            Parma(data.notes[noteIndex].content, render: MyRender())
                .padding(.top, 5.0)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .onTapGesture {
                    self.showEdit = true
                }
                .fullScreenCover(isPresented: $showEdit, onDismiss: {                                  
                                    showEdit = false }) {
                        NoteEdit(note: note)
                            .environmentObject(data)
                            .environmentObject(index)
                }
                .environmentObject(data)
                .environmentObject(index)
            
            
        }        
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

//struct NoteView_Previews: PreviewProvider {
//    static var previews: some View {
//        NoteView(note: DataManager.sampleNotes[0])
//    }
//}

enum ShowSheet
{
    case yes
    case no
}

extension ShowSheet: Identifiable {
    var id: ShowSheet { self }
}
