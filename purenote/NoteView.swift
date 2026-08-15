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

        GeometryReader { geo in
            ScrollView {
                Markdown(content)
                    .markdownTheme(.purnote)
                    .padding(.top, 10.0)
                    .padding(.horizontal, 20.0)
                    // fill the height of the scroll view so the tap target is
                    // the whole page, not just the glyphs. Tapping the empty
                    // space below a short note now opens the editor too, which
                    // is where a tap most obviously means "let me write here".
                    .frame(maxWidth: .infinity, minHeight: geo.size.height, alignment: .topLeading)
                    .environmentObject(data)
                    .environmentObject(index)
                    .onChange(of: monitor.changeCount) { reloadFromDisk() }
            }
            .scrollContentBackground(.hidden)
            .background(Color.purnotePaper)
        }
        // the gesture and the cover live on the ScrollView, so the whole
        // visible area is tappable rather than only the rendered text
        .contentShape(Rectangle())
        .onTapGesture {
            self.showEdit = true
        }
        .fullScreenCover(isPresented: $showEdit, onDismiss: {
                            showEdit = false }) {
                NoteEdit(note: note)
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
        // a soft, rounded checkbox instead of the default hard SF square --
        // amber when ticked, a quiet hollow box when not
        .taskListMarker { configuration in
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .strokeBorder(
                    configuration.isCompleted
                        ? Color(UIColor.systemOrange)
                        : Color(UIColor.tertiaryLabel),
                    lineWidth: 1.7
                )
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(configuration.isCompleted ? Color(UIColor.systemOrange) : .clear)
                )
                .overlay {
                    if configuration.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .frame(width: 18, height: 18)
                .padding(.trailing, 4)
        }
        // Headings are set in a serif -- the same voice as the note titles in
        // the list. It is Purnote's one deliberate step away from the all-SF
        // look of Notes, and it reads warmer for something you sat down to write.
        .heading1 { configuration in
            configuration.label
                .markdownMargin(top: .rem(0.4), bottom: .rem(0.5))
                .markdownTextStyle {
                    FontFamily(.system(.serif))
                    FontWeight(.bold)
                    FontSize(.em(1.8))
                }
        }
        .heading2 { configuration in
            configuration.label
                .markdownMargin(top: .rem(0.9), bottom: .rem(0.4))
                .markdownTextStyle {
                    FontFamily(.system(.serif))
                    FontWeight(.semibold)
                    FontSize(.em(1.4))
                }
        }
        .heading3 { configuration in
            configuration.label
                .markdownMargin(top: .rem(0.8), bottom: .rem(0.3))
                .markdownTextStyle {
                    FontFamily(.system(.serif))
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
