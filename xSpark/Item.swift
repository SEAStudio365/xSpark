//
//  Item.swift
//  xSpark
//
//  Created by Lysander on 2026/7/2.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
