//
//  DocumentPickerViewController.swift
//  Purnote
//
//  Created by Saša Mitrović on 28.10.20.
//

import Foundation
import UIKit
import SwiftUI
import UniformTypeIdentifiers

struct DocumentPickerViewController: UIViewControllerRepresentable {
    let supportedTypes: [UTType] = [UTType.folder]

    
    var callback: (URL) -> ()
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(documentController: self)
    }
    
    func updateUIViewController(
        _ uiViewController: UIDocumentPickerViewController,
        context: UIViewControllerRepresentableContext<DocumentPickerViewController>) {
    }
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: supportedTypes)
        controller.delegate = context.coordinator
        controller.directoryURL = iCloudConnection.getConnection().rootUrl
        return controller
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var documentController: DocumentPickerViewController
        
        init(documentController: DocumentPickerViewController) {
            self.documentController = documentController
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first, url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            documentController.callback(urls[0])
        }
    }
}
