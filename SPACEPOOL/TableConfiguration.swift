//
//  TableConfiguration.swift
//  SpacePool
//
//  Created by Thomas Harris-Warrick on 1/17/26.
//

import SpriteKit

/// Configuration for pool table appearance and layout
struct TableConfiguration {
    // MARK: - Selected Scheme
    var selectedSchemeIndex: Int
    
    // Reference to the global theme colors from StarfieldScene
    var feltColor: SKColor {
        return StarfieldScene.ThemeColor1
    }
    
    var frameColor: SKColor {
        return StarfieldScene.ThemeColor2
    }
    
    // MARK: - Initialization
    init(randomSchemeIndex: Int) {
        self.selectedSchemeIndex = randomSchemeIndex
    }
    
    static func randomScheme() -> TableConfiguration {
        let index = Int.random(in: 0..<12) // Match the 12 color schemes in StarfieldScene
        return TableConfiguration(randomSchemeIndex: index)
    }
}
