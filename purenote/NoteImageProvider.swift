//
//  NoteImageProvider.swift
//  purenote
//

import SwiftUI
import MarkdownUI

/// Loads a note's own images from disk.
///
/// MarkdownUI resolves each `![](<My Note.assets/photo.jpg>)` against the
/// note's directory (the `imageBaseURL` we pass to every `Markdown`), so by the
/// time this runs the URL is a file URL. Anything else — an http(s) image — is
/// handed to MarkdownUI's network loader, keeping the old behaviour.
struct NoteImageProvider: ImageProvider {

    @ViewBuilder func makeImage(url: URL?) -> some View {
        if let url {
            if url.isFileURL {
                if let image = UIImage(contentsOfFile: url.path) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                // a local path whose file is missing renders nothing rather
                // than a broken-image glyph
            } else {
                DefaultImageProvider().makeImage(url: url)
            }
        }
    }
}
