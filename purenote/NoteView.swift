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
    @EnvironmentObject var monitor: iCloudMonitor
    var note:Note
    /// Content read straight off disk after iCloud reported a change. The
    /// enclosing MenuView stops refreshing once a note is pushed on top of it,
    /// so without this a note edited on the Mac stayed stale exactly while you
    /// were looking at it.
    @State private var liveContent: String?
    @State var showEdit  = false
    @State var text = "some content to edit"


    /// The note as the list currently knows it, falling back to the copy this
    /// view was handed. Looking it up by index and force unwrapping crashed
    /// whenever a note was deleted or renamed on the Mac while it was open
    /// here -- which, for an app whose files are meant to be edited elsewhere,
    /// is ordinary rather than exceptional.
    var content: String {
        liveContent ?? data.notes.first(where: { $0.id == note.id })?.content ?? note.content
    }

    private func reloadFromDisk() {
        guard let updated = try? CoordinatedFile.read(note.url) else { return }
        liveContent = updated
        note.content = updated
    }

    var body: some View {

        ScrollView {
            Markdown(content)
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
                .onChange(of: monitor.changeCount) { reloadFromDisk() }


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
