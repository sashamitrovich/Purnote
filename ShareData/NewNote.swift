//
//  NewBook.swift
//  ShareData
//
//  Created by Saša Mitrović on 03.10.20.
//

import SwiftUI

//struct ResponderTextField: UIViewRepresentable {
//
//    typealias TheUIView = UITextField
//    var isFirstResponder: Bool
//    var configuration = { (view: TheUIView) in }
//
//    func makeUIView(context: UIViewRepresentableContext<Self>) -> TheUIView { TheUIView() }
//    func updateUIView(_ uiView: TheUIView, context: UIViewRepresentableContext<Self>) {
//        _ = isFirstResponder ? uiView.becomeFirstResponder() : uiView.resignFirstResponder()
//        configuration(uiView)
//    }
//}

struct NewNote: View {
    @EnvironmentObject var data: Data
//    @State var newNote: Note
    @State var newNote: Note
    
    
    var body: some View {
        VStack {
            //            TextEditor(text: $data.note[data.note.count-1].title)
            
            TextEditor(text: $newNote.content)
            
            
            //            ResponderTextField(isFirstResponder: true ) {
            //                uiView in
            //                uiView.placeholder="text here"
            //            }
            //            Text(data.note[data.note.count-1].id)
            
        }
        .onAppear(perform: {
//            data.note.append(Note())
            newNote=Note()
            
        }
        )
        .onDisappear(perform: {
            //            if data.note[data.note.count-1].title == "" {
            //                data.note.remove(at: data.note.count-1)
            //            }
            //
            if newNote.content != "" {
                data.addSaveNote(newNote: &newNote)
            }
        })
    }
}

struct NewNote_Previews: PreviewProvider {
    @State static var newNote = Note()    
    static var previews: some View {
        let newNote = Note()
        NewNote(newNote: newNote).environmentObject(Data())
    }
}
