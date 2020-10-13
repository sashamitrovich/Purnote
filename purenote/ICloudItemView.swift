//
//  testView.swift
//  ShareData
//
//  Created by Saša Mitrović on 08.10.20.
//

import SwiftUI

struct ICloudItemView: View {
    @EnvironmentObject var data: DataManager
    
//    var index: Int = 0
    @State var note : Note
    
    var body: some View {
        HStack {
            
            
                Text(note.label)
                    .frame(width: 300.0, alignment: .leading)
                if note.isDownloading {
                    ProgressView().progressViewStyle(CircularProgressViewStyle.init())
                }
                else {
                Image(systemName: "icloud.and.arrow.down")
                }
        }.onTapGesture() {
            note.isDownloading = true
            download()

        }
    }
    
    func download() {
    
        data.concurrentQueue.async { [self] in
            
            
            data.delayWithSeconds(trseconds: 3, completion: {print("waiting")})
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
                note.content = try String(contentsOf: URL(fileURLWithPath: downloadedFilePath), encoding: String.Encoding.utf8)
            }
            catch {
                /* error handling here */
                print("Unexpected error: \(error).")
            }
            
            do {
                note.date = try FileManager.default.attributesOfItem(atPath: downloadedFilePath)[.creationDate] as! Date
            }
            catch {
                /* error handling here */
                print("Unexpected error: \(error).")
            }
 
            note.url = URL(fileURLWithPath: downloadedFilePath)
            note.isLocal = true;

            
        }
    }
}


//struct testView_Previews: PreviewProvider {
//    static var previews: some View {
//        DownloadiCloudItemView(index: 0).environmentObject(DataManager())
//    }
//}
