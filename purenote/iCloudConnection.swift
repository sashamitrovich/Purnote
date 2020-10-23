//
//  iCloudConnection.swift
//  purenote
//
//  Created by Saša Mitrović on 23.10.20.
//

import Foundation

class iCloudConnection {

    
    public static func getConnection() -> Connection {
        return connect()
    }
        
    
    private static func connect() -> Connection {
        var myConnection = Connection()
        let fm = FileManager.default
        myConnection.connectionAvailable = true
        
        // First get the URL for the default ubiquity container for this app
        if let containerURL = fm.url(forUbiquityContainerIdentifier: nil) {
            myConnection.rootUrl = containerURL.appendingPathComponent("Documents")
            
            do {
                if (fm.fileExists(atPath: myConnection.rootUrl.path, isDirectory: nil) == false) {
                    try  fm.createDirectory(at: myConnection.rootUrl, withIntermediateDirectories: true, attributes: nil)
                }
                
                
            } catch {
                print("ERROR: Cannot create /Documents on iCloud")
                myConnection.connectionAvailable = false
                
            }
        } else {
            print("ERROR: Cannot get ubiquity container")
            myConnection.connectionAvailable = false
        }
        
        return myConnection
    }
    
    public func updateConnection(connection: inout Connection) {
        connection = iCloudConnection.connect()
    }
    
}
