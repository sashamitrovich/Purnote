//
//  testView.swift
//  ShareData
//
//  Created by Saša Mitrović on 08.10.20.
//

import SwiftUI

struct ICloudItemView: View {
    @EnvironmentObject var data: DataManager
    @State var note : Note
    @State private var isDownloading = false
    
    var noteIndex: Int {
        data.notes.firstIndex(where: { $0.id == note.id }) ?? Int.max
    }
    
    @ViewBuilder
    var body: some View {
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
        .padding(.top, 11.0)
        .onTapGesture() {
            if !isDownloading {
                isDownloading.toggle()
                
                DispatchQueue.main.asyncAfter(deadline: .now()+1) {
                    
                    download()
                }
            }
        }
    }
    
    func download() {
        data.notes[noteIndex].isDownloading = true
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
        
        // now we can display it as a local file
        
        
        
        do {
            data.notes[noteIndex].content = try String(contentsOf: URL(fileURLWithPath: downloadedFilePath), encoding: String.Encoding.utf8)
        }
        catch {
            /* error handling here */
            print("Unexpected error: \(error).")
        }
        
        do {
            data.notes[noteIndex].date = try FileManager.default.attributesOfItem(atPath: downloadedFilePath)[.creationDate] as! Date
        }
        catch {
            /* error handling here */
            print("Unexpected error: \(error).")
        }
        
        data.refresh(url: data.getCurrentUrl())
        
        
    }
}

struct ICloudItemView_Previews: PreviewProvider {
    static var previews: some View {
        ICloudItemView(note: DataManager.sampleDataManager().notes[0])
            .environmentObject(DataManager.sampleDataManager())
    }
}
