//
//  testView.swift
//  ShareData
//
//  Created by Saša Mitrović on 08.10.20.
//

import SwiftUI

struct ICloudItemView: View {
    @EnvironmentObject var data: DataManager
    @EnvironmentObject var index: SearchIndex
    @State var note : Note
    @State private var isDownloading = false
    
    @ViewBuilder
    var body: some View {
        VStack(alignment: .leading) {
            Text(note.date.toString())
                .fontWeight(.light)
                .multilineTextAlignment(.leading)
//                .foregroundColor(Color(UIColor.placeholderText))
            
            HStack {
                
                
                Text(note.label)
                    .frame(maxWidth: .infinity, alignment: .leading)
                  
                
                if self.isDownloading {
                    ProgressView().progressViewStyle(CircularProgressViewStyle.init())
                }
                else {
                    Image(systemName: "icloud.and.arrow.down")
                        .frame(alignment: .trailing)
                }
            }
            .padding(.bottom, 10.0)
//            .padding(.top, 1.0)
            .onTapGesture() {
                if !isDownloading {
                    isDownloading.toggle()
                    
                    DispatchQueue.main.asyncAfter(deadline: .now()+1) {
                        
                        download()
                    }
                }
        }
        }
    }
    
    /// Starts the iCloud download and turns the row into a normal local note
    /// once the file is actually there.
    ///
    /// The wait must not run on the main thread: this used to be a `while`
    /// loop checking `fileExists`, which froze the UI for the whole download
    /// and for ever if iCloud stalled. The wait now polls on a detached task
    /// and gives up after a timeout, leaving the row as it was so a tap can
    /// simply try again.
    func download() {
        guard let note = data.notes.first(where: { $0.id == self.note.id }) else { return }
        note.isDownloading = true

        let placeholder = note.url
        let downloaded = ICloudPlaceholder.downloadedURL(for: placeholder)

        do {
            try FileManager.default.startDownloadingUbiquitousItem(at: placeholder)
        }
        catch {
            /* error handling here */
            print("Failed to start download for \(placeholder.lastPathComponent): \(error).")
            note.isDownloading = false
            isDownloading = false
            return
        }

        Task.detached(priority: .userInitiated) {
            await ICloudPlaceholder.waitForDownload(at: downloaded, timeout: .seconds(60))

            let exists = FileManager.default.fileExists(atPath: downloaded.path)
            let content = exists ? try? CoordinatedFile.read(downloaded) : nil
            let date: Date
            if exists {
                date = (try? FileManager.default.attributesOfItem(atPath: downloaded.path)[.creationDate] as? Date) ?? Date()
            } else {
                date = Date()
            }

            await MainActor.run {
                guard let current = data.notes.first(where: { $0.id == note.id }) else { return }
                current.isDownloading = false
                isDownloading = false

                guard exists, let content else { return }
                current.content = content
                current.date = date
                current.url = downloaded
                current.isLocal = true

                data.refresh(url: data.getCurrentUrl())
                index.indexall()
            }
        }
    }
}

/// The small amount of URL arithmetic around an iCloud `.icloud` placeholder,
/// plus the wait for the file it stands in for. Extracted from the view so it
/// can be unit tested.
enum ICloudPlaceholder {

    /// The file a placeholder stands in for. The placeholder for `note.md` is
    /// named `.note.md.icloud`, so the eventual file is the placeholder's own
    /// name with the leading dot and the `.icloud` suffix removed. Names that
    /// do not follow that shape are returned unchanged.
    static func downloadedURL(for placeholder: URL) -> URL {
        var name = placeholder.lastPathComponent
        if name.hasPrefix(".") { name.removeFirst() }
        if name.hasSuffix(".icloud") {
            name = String(name.dropLast(".icloud".count))
        }
        return placeholder.deletingLastPathComponent().appendingPathComponent(name)
    }

    /// Polls until the file exists or the timeout passes. A failed download
    /// leaves the placeholder behind and the file never appears, so without a
    /// deadline this would wait forever.
    static func waitForDownload(at url: URL,
                                timeout: Duration,
                                pollingEvery interval: Duration = .milliseconds(500)) async {
        let deadline = ContinuousClock.now + timeout
        while !FileManager.default.fileExists(atPath: url.path) {
            if ContinuousClock.now > deadline { return }
            try? await Task.sleep(for: interval)
        }
    }
}

struct ICloudItemView_Previews: PreviewProvider {
    static var previews: some View {
        ICloudItemView(note: DataManager.sampleDataManager().notes[0])
            .environmentObject(DataManager.sampleDataManager())
            .environmentObject(SearchIndex(rootUrl: URL(fileURLWithPath: "")))
    }
}
