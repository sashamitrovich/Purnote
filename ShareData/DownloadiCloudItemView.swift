//
//  testView.swift
//  ShareData
//
//  Created by Saša Mitrović on 08.10.20.
//

import SwiftUI

struct DownloadiCloudItemView: View {
    @EnvironmentObject var data: Data
    
    var note: Note
    var body: some View {
        HStack {
            Text(note.url.lastPathComponent.replacingOccurrences(of: ".icloud", with: "").dropFirst())
                .frame(width: 300.0, alignment: .leading)
            Image(systemName: "icloud.and.arrow.down")
        }.onTapGesture(count: /*@START_MENU_TOKEN@*/1/*@END_MENU_TOKEN@*/, perform: {
            print("tapping")
            download(note: note)
        })
    }
    
    func download(note: Note) {
        
        let concurrentQueue = DispatchQueue(label: "mitrovic.concurrent.queue", attributes: .concurrent)
        
        concurrentQueue.async { [self] in
            
            // start downloading item
            do {
                try FileManager.default.startDownloadingUbiquitousItem(at: note.url)
                
            }
            catch {
                /* error handling here */
                print("Unexpected error: \(error).")
            }
            
            //
            //
            // wait for item to download
            
            // Delete the "." which is at the beginning of the icloud file name
            var lastPathComponent = note.url.lastPathComponent
            lastPathComponent.removeFirst()
            // Get folder path without the last component
            let folderPath = note.url.deletingLastPathComponent().path
            // Create the downloaded file path
            let downloadedFilePath = folderPath + "/" + lastPathComponent.replacingOccurrences(of: ".icloud", with: "")
            var isDownloaded = false
            // Create a loop until isDownloaded is true
            while !isDownloaded {
              // Check if the file is downloaded
                if FileManager.default.fileExists(atPath: downloadedFilePath) {
                isDownloaded = true
              }
            }
            
            data.refresh()
        }
    }
}


struct testView_Previews: PreviewProvider {
    static var previews: some View {
        DownloadiCloudItemView(note: Note(content: "some note content", date: Date(), path: "note.md", isLocal: false, url: URL(fileURLWithPath: "/some/file.txt"))).environmentObject(Data())
    }
}
