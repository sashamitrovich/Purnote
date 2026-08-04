//
//  NoteView.swift
//  Purnote
//
//  Created by Saša Mitrović on 29.10.20.
//

import SwiftUI
import MarkdownUI

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
            Markdown(data.notes[noteIndex].content)
                .markdownTheme(.purnote)
                .padding(.top, 5.0)
                .padding(.horizontal, 5.0)
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


extension Theme {
    /// Purnote's rendering: the basic theme with a tighter vertical rhythm
    /// (notes usually open with a heading, so 1.5rem of space above it is
    /// wasted) and links in the app's orange.
    static let purnote = Theme.basic
        .link {
            ForegroundColor(Color(UIColor.systemOrange))
        }
        .heading1 { configuration in
            configuration.label
                .markdownMargin(top: .rem(0.4), bottom: .rem(0.5))
                .markdownTextStyle {
                    FontWeight(.bold)
                    FontSize(.em(1.8))
                }
        }
        .heading2 { configuration in
            configuration.label
                .markdownMargin(top: .rem(0.9), bottom: .rem(0.4))
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(.em(1.4))
                }
        }
        .heading3 { configuration in
            configuration.label
                .markdownMargin(top: .rem(0.8), bottom: .rem(0.3))
                .markdownTextStyle {
                    FontWeight(.semibold)
                    FontSize(.em(1.15))
                }
        }
        .paragraph { configuration in
            configuration.label
                .relativeLineSpacing(.em(0.2))
                .markdownMargin(top: .zero, bottom: .rem(0.6))
        }
        // the default code block does not scroll, so long lines are simply
        // cut off at the right edge of the screen
        .codeBlock { configuration in
            ScrollView(.horizontal) {
                configuration.label
                    .relativeLineSpacing(.em(0.2))
                    .markdownTextStyle {
                        FontFamilyVariant(.monospaced)
                        FontSize(.em(0.9))
                    }
                    .padding(10)
            }
            .background(Color(UIColor.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .markdownMargin(top: .zero, bottom: .rem(0.8))
        }
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
