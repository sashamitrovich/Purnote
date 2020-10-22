//
//  StringProtocol.swift
//  purenote
//
//  Created by Saša Mitrović on 22.10.20.
//

import Foundation

extension StringProtocol {
    var words: [SubSequence] {
        split(whereSeparator: \.isLetter.negation)
    }
}

extension Bool {
    var negation: Bool { !self }
}
