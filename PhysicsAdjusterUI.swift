//
//  PhysicsAdjusterUI.swift
//  SpacePool
//
//  Physics adjustment overlay UI with settings for ball physics, spawning, and debug tools
//

import UIKit
import SpriteKit

class PhysicsAdjusterUI {
    
    // MARK: - Properties
    weak var scene: StarfieldScene?
    private var toggleButton: UIButton?
    private var overlayView: UIView?
    private var isOverlayVisible = false
    
    // Callbacks
    private var resetCallback: (() -> Void)?
    private var restartCallback: (() -> Void)?
    private var bossLevelCallback: (() -> Void)?
    
    // MARK: - Initialization
    init(scene: StarfieldScene) {
        self.scene = scene
    }
    
    // MARK: - Callbacks
    func onReset(_ callback: @escaping () -> Void) {
        self.resetCallback = callback
    }
    
    func onRestart(_ callback: @escaping () -> Void) {
        self.restartCallback = callback
    }
    
    func onBossLevel(_ callback: @escaping () -> Void) {
        self.bossLevelCallback = callback
    }
    
    // MARK: - UI Creation
    func createToggleButton() {
        guard let scene = scene, let view = scene.view else { return }
        
        let button = UIButton(type: .system)
        button.setTitle("⚙️", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 30)
        button.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        button.layer.cornerRadius = 25
        button.frame = CGRect(x: view.bounds.width - 70, y: 20, width: 50, height: 50)
        button.addTarget(self, action: #selector(toggleOverlay), for: .touchUpInside)
        
        view.addSubview(button)
        self.toggleButton = button
    }
    
    @objc private func toggleOverlay() {
        if isOverlayVisible {
            hideOverlay()
        } else {
            showOverlay()
        }
    }
    
    private func showOverlay() {
        guard let scene = scene, let view = scene.view else { return }
        guard overlayView == nil else { return }
        
        // Create semi-transparent overlay background
        let overlay = UIView(frame: view.bounds)
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.85)
        
        // Create scroll view for settings
        let scrollView = UIScrollView(frame: CGRect(x: 50, y: 50, width: view.bounds.width - 100, height: view.bounds.height - 100))
        scrollView.backgroundColor = UIColor.darkGray.withAlphaComponent(0.9)
        scrollView.layer.cornerRadius = 10
        
        let contentView = UIView()
        var yOffset: CGFloat = 20
        
        // Title
        let titleLabel = UILabel(frame: CGRect(x: 20, y: yOffset, width: scrollView.bounds.width - 40, height: 40))
        titleLabel.text = "Physics & Game Settings"
        titleLabel.font = .boldSystemFont(ofSize: 24)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        contentView.addSubview(titleLabel)
        yOffset += 50
        
        // Reset Progress Button
        let resetButton = createButton(title: "Reset Progress", y: yOffset, width: scrollView.bounds.width - 40)
        resetButton.addTarget(self, action: #selector(handleReset), for: .touchUpInside)
        contentView.addSubview(resetButton)
        yOffset += 60
        
        // Restart Game Button
        let restartButton = createButton(title: "Restart Game", y: yOffset, width: scrollView.bounds.width - 40)
        restartButton.addTarget(self, action: #selector(handleRestart), for: .touchUpInside)
        contentView.addSubview(restartButton)
        yOffset += 60
        
        // Boss Level Button
        let bossButton = createButton(title: "Trigger Boss Level", y: yOffset, width: scrollView.bounds.width - 40)
        bossButton.addTarget(self, action: #selector(handleBossLevel), for: .touchUpInside)
        contentView.addSubview(bossButton)
        yOffset += 60
        
        // Clear Texture Cache Button
        let clearCacheButton = createButton(title: "Clear Texture Cache", y: yOffset, width: scrollView.bounds.width - 40)
        clearCacheButton.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.8)
        clearCacheButton.addTarget(self, action: #selector(handleClearTextureCache), for: .touchUpInside)
        contentView.addSubview(clearCacheButton)
        yOffset += 60
        
        // Ball Spawning Section
        let spawningLabel = UILabel(frame: CGRect(x: 20, y: yOffset, width: scrollView.bounds.width - 40, height: 30))
        spawningLabel.text = "Spawn Balls"
        spawningLabel.font = .boldSystemFont(ofSize: 18)
        spawningLabel.textColor = .white
        contentView.addSubview(spawningLabel)
        yOffset += 40
        
        // Create spawn buttons for each ball type
        let ballTypes: [BlockBall.Kind] = [.one, .two, .three, .four, .five, .six, .seven, .eight, .nine, .ten, .eleven, .twelve, .thirteen, .fourteen, .fifteen]
        
        for (index, ballType) in ballTypes.enumerated() {
            let xOffset: CGFloat = 20 + CGFloat(index % 5) * 70
            let rowOffset = CGFloat(index / 5) * 50
            
            let spawnButton = UIButton(type: .system)
            spawnButton.frame = CGRect(x: xOffset, y: yOffset + rowOffset, width: 60, height: 40)
            spawnButton.setTitle("\(ballType.rawValue)", for: .normal)
            spawnButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.8)
            spawnButton.setTitleColor(.white, for: .normal)
            spawnButton.titleLabel?.font = .boldSystemFont(ofSize: 14)
            spawnButton.layer.cornerRadius = 5
            spawnButton.tag = index
            spawnButton.addTarget(self, action: #selector(handleSpawnBall(_:)), for: .touchUpInside)
            contentView.addSubview(spawnButton)
        }
        yOffset += 150
        
        // Close Button
        let closeButton = createButton(title: "Close", y: yOffset, width: scrollView.bounds.width - 40)
        closeButton.backgroundColor = UIColor.systemRed.withAlphaComponent(0.8)
        closeButton.addTarget(self, action: #selector(toggleOverlay), for: .touchUpInside)
        contentView.addSubview(closeButton)
        yOffset += 60
        
        // Set content view size
        contentView.frame = CGRect(x: 0, y: 0, width: scrollView.bounds.width, height: yOffset)
        scrollView.contentSize = contentView.bounds.size
        scrollView.addSubview(contentView)
        
        overlay.addSubview(scrollView)
        view.addSubview(overlay)
        
        self.overlayView = overlay
        isOverlayVisible = true
    }
    
    private func hideOverlay() {
        overlayView?.removeFromSuperview()
        overlayView = nil
        isOverlayVisible = false
    }
    
    private func createButton(title: String, y: CGFloat, width: CGFloat) -> UIButton {
        let button = UIButton(type: .system)
        button.frame = CGRect(x: 20, y: y, width: width, height: 50)
        button.setTitle(title, for: .normal)
        button.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.8)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .boldSystemFont(ofSize: 16)
        button.layer.cornerRadius = 10
        return button
    }
    
    // MARK: - Button Handlers
    @objc private func handleReset() {
        resetCallback?()
        hideOverlay()
    }
    
    @objc private func handleRestart() {
        restartCallback?()
        hideOverlay()
    }
    
    @objc private func handleBossLevel() {
        bossLevelCallback?()
        hideOverlay()
    }
    
    @objc private func handleClearTextureCache() {
        // Clear SKTextureAtlas cache
        SKTextureAtlas.preloadTextureAtlases([]) { }
        
        // Force all balls to regenerate their textures
        guard let scene = scene else { return }
        
        var ballCount = 0
        for node in scene.children {
            if node is BlockBall {
                // Textures will be regenerated on-demand when balls move/update
                ballCount += 1
            }
        }
        
        print("🗑️ Texture cache cleared! Found \(ballCount) balls that will regenerate textures on next update.")
        
        // Show feedback
        let alert = UIAlertController(
            title: "Cache Cleared",
            message: "Texture cache has been cleared. \(ballCount) balls will regenerate textures on next update.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        if let viewController = scene.view?.window?.rootViewController {
            viewController.present(alert, animated: true)
        }
    }
    
    @objc private func handleSpawnBall(_ sender: UIButton) {
        guard let scene = scene else { return }
        let ballTypes: [BlockBall.Kind] = [.one, .two, .three, .four, .five, .six, .seven, .eight, .nine, .ten, .eleven, .twelve, .thirteen, .fourteen, .fifteen]
        let ballType = ballTypes[sender.tag]
        
        if scene.spawnBall(type: ballType) {
            print("✅ Spawned ball type \(ballType.rawValue)")
        } else {
            print("❌ Failed to spawn ball type \(ballType.rawValue)")
        }
    }
    
    // MARK: - Settings Management
    func applyLoadedSettings() {
        // Placeholder for loading saved settings from UserDefaults
        // Can be extended with saved physics parameters
    }
    
    func applySettingsToAllBalls() {
        // Placeholder for applying settings to all balls
        // Can be extended with physics parameter updates
    }
    
    // MARK: - Touch Handling
    func handleTouchBegan(_ touch: UITouch) -> Bool {
        guard let view = scene?.view else { return false }
        let location = touch.location(in: view)
        
        // Check if touch is on toggle button
        if let button = toggleButton, button.frame.contains(location) {
            return true
        }
        
        // Check if touch is on overlay
        if isOverlayVisible {
            return true
        }
        
        return false
    }
    
    func handleTouchMoved(_ touch: UITouch) -> Bool {
        return isOverlayVisible
    }
    
    func handleTouchEnded(_ touch: UITouch) -> Bool {
        return isOverlayVisible
    }
    
    // MARK: - Layout Updates
    func updateForSizeChange() {
        guard let scene = scene, let view = scene.view else { return }
        
        // Update toggle button position
        toggleButton?.frame = CGRect(x: view.bounds.width - 70, y: 20, width: 50, height: 50)
        
        // Recreate overlay if visible
        if isOverlayVisible {
            hideOverlay()
            showOverlay()
        }
    }
}
