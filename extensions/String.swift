//
//  String.swift
//  purenoteTests
//
//  Created by Saša Mitrović on 20.10.20.
//

import Foundation

extension String {
    public func removePuncuation() -> String {
        return self
            .replacingOccurrences(of: ".", with: " ")
            .replacingOccurrences(of: ",", with: " ")
            .replacingOccurrences(of: "'", with: " ")
            .replacingOccurrences(of: ":", with: " ")
            .replacingOccurrences(of: ";", with: " ")
            .replacingOccurrences(of: "?", with: " ")
            .replacingOccurrences(of: "!", with: " ")
            .replacingOccurrences(of: "-", with: " ")
    }
}
