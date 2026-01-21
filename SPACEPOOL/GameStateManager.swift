//
//  GameStateManager.swift
//  SpacePool
//
//  Created by Thomas Harris-Warrick on 1/17/26.
//

import Foundation
import SpriteKit

/// Manages game progression state including level and score tracking
class GameStateManager {
    // MARK: - Properties
    private(set) var currentLevel: Int = 1
    private(set) var currentScore: Int = 0
    private(set) var currentDifficulty: Int = 0
    
    // UI labels (weak references to update external labels)
    weak var levelValueLabel: SKLabelNode?
    weak var scoreValueLabel: SKLabelNode?
    
    // MARK: - Initialization
    init() {
        // Load saved progress or start at defaults
        loadLevel()
        loadScore()
        loadDifficulty()
        print("🎮 App launched: Starting at level \(currentLevel), score \(currentScore), difficulty \(currentDifficulty)")
    }
    
    // MARK: - Level Management
    func advanceToNextLevel() {
        let newLevel = currentLevel + 1
        saveLevel(newLevel)
        incrementDifficulty()
        print("🆙 Advanced to level \(newLevel)")
    }
    
    func resetLevel() {
        saveLevel(1)
    }
    
    // MARK: - Score Management
    func addScore(_ points: Int) {
        let newScore = currentScore + points
        saveScore(newScore)
    }
    
    func setScore(_ score: Int) {
        saveScore(score)
    }
    
    func resetScore() {
        saveScore(0)
    }
    
    func resetProgress() {
        resetLevel()
        resetScore()
        resetDifficulty()
        print("🔄 Progress reset to level 1, score 0, difficulty 0")
    }
    
    // MARK: - Difficulty
    func resetDifficulty() {
        saveDifficulty(0)
    }
    
    func incrementDifficulty() {
        saveDifficulty(currentDifficulty + 1)
    }
    
    // MARK: - Private Persistence
    private func loadLevel() {
        let defaults = UserDefaults.standard
        let levelKey = "CurrentLevel"
        
        if let savedLevel = defaults.object(forKey: levelKey) as? Int, savedLevel > 0 {
            currentLevel = savedLevel
            print("📊 Loaded level: \(currentLevel)")
        } else {
            currentLevel = 1
            defaults.set(currentLevel, forKey: levelKey)
            print("📊 Starting at level 1")
        }
    }
    
    private func saveLevel(_ level: Int) {
        currentLevel = level
        let defaults = UserDefaults.standard
        defaults.set(currentLevel, forKey: "CurrentLevel")
        print("📊 Saved level: \(currentLevel)")
        
        // Update label if connected (preserve existing font color)
        if let label = levelValueLabel {
            let existingColor = label.fontColor
            label.text = "\(currentLevel)"
            label.fontColor = existingColor  // Restore color to prevent changes
        }
    }
    
    private func loadScore() {
        let defaults = UserDefaults.standard
        let scoreKey = "CurrentScore"
        
        if let savedScore = defaults.object(forKey: scoreKey) as? Int, savedScore >= 0 {
            currentScore = savedScore
            print("🎯 Loaded score: \(currentScore)")
        } else {
            currentScore = 0
            defaults.set(currentScore, forKey: scoreKey)
            print("🎯 Starting at score 0")
        }
    }
    
    private func saveScore(_ score: Int) {
        currentScore = score
        let defaults = UserDefaults.standard
        defaults.set(currentScore, forKey: "CurrentScore")
        
        // Update label if connected (preserve existing font color)
        if let label = scoreValueLabel {
            let existingColor = label.fontColor
            label.text = "\(currentScore)"
            label.fontColor = existingColor  // Restore color to prevent changes
        }
        
        print("🎯 Saved score: \(currentScore)")
    }
    
    private func loadDifficulty() {
        let defaults = UserDefaults.standard
        let key = "CurrentDifficulty"
        if let saved = defaults.object(forKey: key) as? Int, saved >= 0 {
            currentDifficulty = saved
            print("📈 Loaded difficulty: \(currentDifficulty)")
        } else {
            currentDifficulty = 0
            defaults.set(currentDifficulty, forKey: key)
            print("📈 Starting at difficulty 0")
        }
    }
    
    private func saveDifficulty(_ value: Int) {
        currentDifficulty = value
        let defaults = UserDefaults.standard
        defaults.set(currentDifficulty, forKey: "CurrentDifficulty")
        print("📈 Saved difficulty: \(currentDifficulty)")
    }
}

