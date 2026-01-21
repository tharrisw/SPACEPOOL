//
//  PhysicsAdjusterUI.swift
//  SpacePool
//
//  Created by Thomas Harris-Warrick on 1/17/26.
//

import Foundation
import SpriteKit
import UIKit

/// Manages the overlay UI for adjusting physics parameters
class PhysicsAdjusterUI {
    // MARK: - Properties
    private weak var scene: SKScene?
    
    private var overlayContainer: SKNode?
    private var overlayBackground: SKShapeNode?
    private var overlayBackdrop: SKShapeNode?  // Darkened background behind overlay
    private var overlayVisible: Bool = false
    var overlayToggleButton: SKShapeNode?  // Made internal for scene access
    
    private var onResetRequested: (() -> Void)?
    private var onRestartRequested: (() -> Void)?
    
    // Toggle buttons for debug features
    private var healthBarsEnabled: Bool = false
    private var damageNumbersEnabled: Bool = false
    private var healthBarsToggle: SKShapeNode?
    private var damageNumbersToggle: SKShapeNode?
    
    // MARK: - UserDefaults Keys
    private enum SettingsKey {
        static let damageMultiplier = "spacepool.damageMultiplier"
        static let maxImpulse = "spacepool.maxImpulse"
        static let threeBallMass = "spacepool.threeBallMass"
        static let maxShotDistance = "spacepool.maxShotDistance"
        static let powerExponent = "spacepool.powerExponent"
        static let friction = "spacepool.friction"
        static let linearDamping = "spacepool.linearDamping"
        static let restitution = "spacepool.restitution"
        static let baseAngularDamping = "spacepool.baseAngularDamping"
        static let highAngularDamping = "spacepool.highAngularDamping"
        static let slowSpeedThreshold = "spacepool.slowSpeedThreshold"
        static let restLinearThreshold = "spacepool.restLinearThreshold"
        static let restAngularThreshold = "spacepool.restAngularThreshold"
        static let restCheckDuration = "spacepool.restCheckDuration"
        static let stopSpeedThreshold = "spacepool.stopSpeedThreshold"
        static let stopAngularThreshold = "spacepool.stopAngularThreshold"
        static let healthBarsEnabled = "spacepool.healthBarsEnabled"
        static let damageNumbersEnabled = "spacepool.damageNumbersEnabled"
        static let fourBallDamageRadius = "spacepool.fourBallDamageRadius"
        static let fourBallMaxTriggers = "spacepool.fourBallMaxTriggers"
    }
    
    // Scrolling support
    private var overlayContentNode: SKNode?
    private var overlayScrollOffset: CGFloat = 0
    private var overlayMaxScrollOffset: CGFloat = 0
    private var overlayScrollVelocity: CGFloat = 0
    private var lastOverlayTouchY: CGFloat = 0
    private var overlayScrolling: Bool = false
    private var overlayScrollStartY: CGFloat = 0
    private var isDraggingSlider: Bool = false  // Track if user is dragging a slider
    
    // Slider bookkeeping
    private var sliderSpecs: [SliderSpec] = []
    private var sliderNodes: [String: (track: SKShapeNode, handle: SKShapeNode, valueLabel: SKLabelNode)] = [:]
    
    // MARK: - Slider Specification
    struct SliderSpec {
        let id: String
        let title: String
        let min: CGFloat
        let max: CGFloat
        let getValue: () -> CGFloat
        let setValue: (CGFloat) -> Void
        let format: (CGFloat) -> String
    }
    
    // MARK: - Initialization
    init(scene: SKScene) {
        self.scene = scene
        loadSettings()
    }
    
    // MARK: - Persistence
    
    /// Load all settings from UserDefaults and apply them to the scene
    private func loadSettings() {
        let defaults = UserDefaults.standard
        
        // Load toggle states
        if defaults.object(forKey: SettingsKey.healthBarsEnabled) != nil {
            healthBarsEnabled = defaults.bool(forKey: SettingsKey.healthBarsEnabled)
        }
        if defaults.object(forKey: SettingsKey.damageNumbersEnabled) != nil {
            damageNumbersEnabled = defaults.bool(forKey: SettingsKey.damageNumbersEnabled)
        }
    }
    
    /// Apply loaded settings to the scene after it's fully initialized
    func applyLoadedSettings() {
        guard let scene = scene as? StarfieldScene else { return }
        let defaults = UserDefaults.standard
        
        // Apply damage system settings
        if defaults.object(forKey: SettingsKey.damageMultiplier) != nil {
            let value = CGFloat(defaults.double(forKey: SettingsKey.damageMultiplier))
            scene.damageSystem?.config.damageMultiplier = value
        }
        
        if defaults.object(forKey: SettingsKey.fourBallDamageRadius) != nil {
            let value = CGFloat(defaults.double(forKey: SettingsKey.fourBallDamageRadius))
            scene.damageSystem?.config.fourBallDamageRadius = value
        }
        
        // 4-Ball Max Triggers (default 2 if not set)
        let savedMaxTriggers = UserDefaults.standard.integer(forKey: SettingsKey.fourBallMaxTriggers)
        if savedMaxTriggers > 0 {
            scene.damageSystem?.config.fourBallMaxTriggers = savedMaxTriggers
        }
        
        // Apply ball physics settings to all existing balls
        applyLoadedSettingsToBalls()
        
        // Apply damage system toggles
        scene.damageSystem?.config.showHealthBars = healthBarsEnabled
        scene.damageSystem?.config.showDamageNumbers = damageNumbersEnabled
        
        if healthBarsEnabled {
            scene.damageSystem?.showAllHealthBars()
        } else {
            scene.damageSystem?.hideAllHealthBars()
        }
        
        print("✅ Settings loaded from UserDefaults")
    }
    
    /// Apply loaded settings to all balls in the scene
    private func applyLoadedSettingsToBalls() {
        guard let scene = scene as? StarfieldScene else { return }
        let defaults = UserDefaults.standard
        
        let hasMaxImpulse = defaults.object(forKey: SettingsKey.maxImpulse) != nil
        let hasMaxShotDistance = defaults.object(forKey: SettingsKey.maxShotDistance) != nil
        let hasPowerExponent = defaults.object(forKey: SettingsKey.powerExponent) != nil
        let hasFriction = defaults.object(forKey: SettingsKey.friction) != nil
        let hasLinearDamping = defaults.object(forKey: SettingsKey.linearDamping) != nil
        let hasRestitution = defaults.object(forKey: SettingsKey.restitution) != nil
        let hasBaseAngDamping = defaults.object(forKey: SettingsKey.baseAngularDamping) != nil
        let hasHighAngDamping = defaults.object(forKey: SettingsKey.highAngularDamping) != nil
        
        for case let ball as BlockBall in scene.children {
            // Apply shooting parameters
            if hasMaxImpulse || hasMaxShotDistance || hasPowerExponent {
                ball.setShootingTuning(
                    maxDistance: hasMaxShotDistance ? CGFloat(defaults.double(forKey: SettingsKey.maxShotDistance)) : nil,
                    maxPower: hasMaxImpulse ? CGFloat(defaults.double(forKey: SettingsKey.maxImpulse)) : nil,
                    powerExponent: hasPowerExponent ? CGFloat(defaults.double(forKey: SettingsKey.powerExponent)) : nil
                )
            }
            
            // Apply physics coefficients
            if hasFriction || hasLinearDamping || hasRestitution {
                ball.applyPhysicsCoefficients(
                    friction: hasFriction ? CGFloat(defaults.double(forKey: SettingsKey.friction)) : nil,
                    linearDamping: hasLinearDamping ? CGFloat(defaults.double(forKey: SettingsKey.linearDamping)) : nil,
                    angularDamping: nil,
                    restitution: hasRestitution ? CGFloat(defaults.double(forKey: SettingsKey.restitution)) : nil
                )
            }
            
            // Apply angular damping properties
            if hasBaseAngDamping {
                ball.baseAngularDamping = CGFloat(defaults.double(forKey: SettingsKey.baseAngularDamping))
            }
            if hasHighAngDamping {
                ball.highAngularDamping = CGFloat(defaults.double(forKey: SettingsKey.highAngularDamping))
            }
            
            // Apply speed thresholds
            if defaults.object(forKey: SettingsKey.slowSpeedThreshold) != nil {
                ball.slowSpeedThreshold = CGFloat(defaults.double(forKey: SettingsKey.slowSpeedThreshold))
            }
            if defaults.object(forKey: SettingsKey.restLinearThreshold) != nil {
                ball.restLinearSpeedThreshold = CGFloat(defaults.double(forKey: SettingsKey.restLinearThreshold))
            }
            if defaults.object(forKey: SettingsKey.restAngularThreshold) != nil {
                ball.restAngularSpeedThreshold = CGFloat(defaults.double(forKey: SettingsKey.restAngularThreshold))
            }
            if defaults.object(forKey: SettingsKey.restCheckDuration) != nil {
                ball.restCheckDuration = CGFloat(defaults.double(forKey: SettingsKey.restCheckDuration))
            }
            if defaults.object(forKey: SettingsKey.stopSpeedThreshold) != nil {
                ball.stopSpeedThreshold = CGFloat(defaults.double(forKey: SettingsKey.stopSpeedThreshold))
            }
            if defaults.object(forKey: SettingsKey.stopAngularThreshold) != nil {
                ball.stopAngularThreshold = CGFloat(defaults.double(forKey: SettingsKey.stopAngularThreshold))
            }
        }
        
        // Apply 3-ball mass
        if defaults.object(forKey: SettingsKey.threeBallMass) != nil {
            let multiplier = CGFloat(defaults.double(forKey: SettingsKey.threeBallMass))
            scene.update3BallMass(multiplier: multiplier)
        }
    }
    
    /// Save a setting value to UserDefaults
    private func saveSetting(_ key: String, value: Any) {
        UserDefaults.standard.set(value, forKey: key)
        UserDefaults.standard.synchronize()
    }
    
    /// Reset all settings to defaults
    func resetSettings() {
        let defaults = UserDefaults.standard
        let keys = [
            SettingsKey.damageMultiplier,
            SettingsKey.maxImpulse,
            SettingsKey.threeBallMass,
            SettingsKey.maxShotDistance,
            SettingsKey.powerExponent,
            SettingsKey.friction,
            SettingsKey.linearDamping,
            SettingsKey.restitution,
            SettingsKey.baseAngularDamping,
            SettingsKey.highAngularDamping,
            SettingsKey.slowSpeedThreshold,
            SettingsKey.restLinearThreshold,
            SettingsKey.restAngularThreshold,
            SettingsKey.restCheckDuration,
            SettingsKey.stopSpeedThreshold,
            SettingsKey.stopAngularThreshold,
            SettingsKey.healthBarsEnabled,
            SettingsKey.damageNumbersEnabled,
            SettingsKey.fourBallDamageRadius,
            SettingsKey.fourBallMaxTriggers
        ]
        
        for key in keys {
            defaults.removeObject(forKey: key)
        }
        defaults.synchronize()
        
        print("🗑️ All settings reset to defaults")
    }
    
    // MARK: - Public API
    func configure(with specs: [SliderSpec]) {
        self.sliderSpecs = specs
    }
    
    func onReset(_ action: @escaping () -> Void) {
        self.onResetRequested = action
    }
    
    func onRestart(_ action: @escaping () -> Void) {
        self.onRestartRequested = action
    }
    
    /// Apply loaded settings to all balls (called after applyPhysicsToAllBalls)
    func applySettingsToAllBalls() {
        applyLoadedSettingsToBalls()
    }
    
    func createToggleButton() {
        guard let scene = scene else { return }
        
        let buttonSize = CGSize(width: 36, height: 36)
        let padding: CGFloat = 16
        let button = SKShapeNode(rectOf: buttonSize, cornerRadius: 8)
        button.name = "overlayToggle"
        button.position = CGPoint(x: scene.size.width - padding - buttonSize.width/2, y: scene.size.height - padding - buttonSize.height/2)
        button.zPosition = 5000
        button.strokeColor = .white
        button.lineWidth = 2
        button.fillColor = .clear

        // Icon: three horizontal lines
        let lineWidth: CGFloat = 18
        let lineHeight: CGFloat = 2
        for i in 0..<3 {
            let y = CGFloat(i - 1) * 6
            let line = SKShapeNode(rectOf: CGSize(width: lineWidth, height: lineHeight), cornerRadius: 1)
            line.position = CGPoint(x: 0, y: y)
            line.fillColor = .white
            line.strokeColor = .clear
            line.zPosition = 1
            button.addChild(line)
        }

        scene.addChild(button)
        overlayToggleButton = button
    }
    
    func toggleVisibility() {
        setOverlayVisible(!overlayVisible)
    }
    
    func updateForSizeChange() {
        guard let scene = scene else { return }
        
        // Reposition toggle button
        if let button = overlayToggleButton {
            let buttonSize = CGSize(width: 36, height: 36)
            let padding: CGFloat = 16
            button.position = CGPoint(x: scene.size.width - padding - buttonSize.width/2, y: scene.size.height - padding - buttonSize.height/2)
        }
        
        if overlayVisible {
            buildOverlay()
        }
    }
    
    // MARK: - Touch Handling
    func handleTouchBegan(_ touch: UITouch) -> Bool {
        guard let scene = scene else { return false }
        
        let loc = touch.location(in: scene)
        
        // Toggle button tap
        if let toggle = overlayToggleButton, toggle.contains(loc) {
            toggleVisibility()
            return true
        }
        
        if overlayVisible, let backdrop = overlayBackdrop, let bg = overlayBackground, let contentNode = overlayContentNode {
            // Check ball preview sprites (these are in bg, not contentNode)
            let locInBG = touch.location(in: bg)
            if let tappedNode = bg.nodes(at: locInBG).first(where: { $0.name?.starts(with: "ballPreview_") == true }) {
                // Extract ball kind from node name
                if let nodeName = tappedNode.name,
                   let kindString = nodeName.split(separator: "_").last {
                    handleBallPreviewTap(kindString: String(kindString))
                    return true
                }
            }
            
            // If tap outside overlayBackground, on backdrop, close overlay
            if backdrop.contains(loc) && !bg.contains(loc) {
                toggleVisibility()
                return true
            }
            
            // Get location in content node for scrollable content
            let locInContent = touch.location(in: contentNode)
            
            // Check if touching a slider
            var touchingSlider = false
            
            // Check damage multiplier slider
            if let track = contentNode.childNode(withName: "//damageMultiplierTrack") as? SKShapeNode,
               let handle = contentNode.childNode(withName: "//damageMultiplierHandle") as? SKShapeNode {
                if handle.contains(locInContent) || track.contains(locInContent) {
                    updateDamageMultiplierSlider(touchLocation: locInContent, track: track, handle: handle)
                    touchingSlider = true
                }
            }
            
            // Check max impulse slider
            if let track = contentNode.childNode(withName: "//maxImpulseTrack") as? SKShapeNode,
               let handle = contentNode.childNode(withName: "//maxImpulseHandle") as? SKShapeNode {
                if handle.contains(locInContent) || track.contains(locInContent) {
                    updateMaxImpulseSlider(touchLocation: locInContent, track: track, handle: handle)
                    touchingSlider = true
                }
            }
            
            // Check 3ball mass slider
            if let track = contentNode.childNode(withName: "//threeBallMassTrack") as? SKShapeNode,
               let handle = contentNode.childNode(withName: "//threeBallMassHandle") as? SKShapeNode {
                if handle.contains(locInContent) || track.contains(locInContent) {
                    update3BallMassSlider(touchLocation: locInContent, track: track, handle: handle)
                    touchingSlider = true
                }
            }
            
            // New sliders' touch began detection:
            // Max Shot Distance
            if let track = contentNode.childNode(withName: "//maxShotDistanceTrack") as? SKShapeNode,
               let handle = contentNode.childNode(withName: "//maxShotDistanceHandle") as? SKShapeNode {
                if handle.contains(locInContent) || track.contains(locInContent) {
                    updateMaxShotDistanceSlider(touchLocation: locInContent, track: track, handle: handle)
                    touchingSlider = true
                }
            }
            
            // Power Curve Exponent
            if let track = contentNode.childNode(withName: "//powerExponentTrack") as? SKShapeNode,
               let handle = contentNode.childNode(withName: "//powerExponentHandle") as? SKShapeNode {
                if handle.contains(locInContent) || track.contains(locInContent) {
                    updatePowerExponentSlider(touchLocation: locInContent, track: track, handle: handle)
                    touchingSlider = true
                }
            }
            
            // 4-Ball Damage Radius
            if let track = contentNode.childNode(withName: "//fourBallRadiusTrack") as? SKShapeNode,
               let handle = contentNode.childNode(withName: "//fourBallRadiusHandle") as? SKShapeNode {
                if handle.contains(locInContent) || track.contains(locInContent) {
                    update4BallRadiusSlider(touchLocation: locInContent, track: track, handle: handle)
                    touchingSlider = true
                }
            }
            
            // 4-Ball Max Triggers slider detection
            if let track = contentNode.childNode(withName: "//fourBallMaxTriggersTrack") as? SKShapeNode,
               let handle = contentNode.childNode(withName: "//fourBallMaxTriggersHandle") as? SKShapeNode {
                if handle.contains(locInContent) || track.contains(locInContent) {
                    update4BallMaxTriggersSlider(at: locInContent)
                    touchingSlider = true
                }
            }
            
            // Friction
            if let track = contentNode.childNode(withName: "//frictionTrack") as? SKShapeNode,
               let handle = contentNode.childNode(withName: "//frictionHandle") as? SKShapeNode {
                if handle.contains(locInContent) || track.contains(locInContent) {
                    updateFrictionSlider(touchLocation: locInContent, track: track, handle: handle)
                    touchingSlider = true
                }
            }
            
            // Linear Damping
            if let track = contentNode.childNode(withName: "//linearDampingTrack") as? SKShapeNode,
               let handle = contentNode.childNode(withName: "//linearDampingHandle") as? SKShapeNode {
                if handle.contains(locInContent) || track.contains(locInContent) {
                    updateLinearDampingSlider(touchLocation: locInContent, track: track, handle: handle)
                    touchingSlider = true
                }
            }
            
            // Base Angular Damping
            if let track = contentNode.childNode(withName: "//baseAngDampingTrack") as? SKShapeNode,
               let handle = contentNode.childNode(withName: "//baseAngDampingHandle") as? SKShapeNode {
                if handle.contains(locInContent) || track.contains(locInContent) {
                    updateBaseAngDampingSlider(touchLocation: locInContent, track: track, handle: handle)
                    touchingSlider = true
                }
            }
            
            // High Angular Damping
            if let track = contentNode.childNode(withName: "//highAngDampingTrack") as? SKShapeNode,
               let handle = contentNode.childNode(withName: "//highAngDampingHandle") as? SKShapeNode {
                if handle.contains(locInContent) || track.contains(locInContent) {
                    updateHighAngDampingSlider(touchLocation: locInContent, track: track, handle: handle)
                    touchingSlider = true
                }
            }
            
            // Slow Speed Threshold
            if let track = contentNode.childNode(withName: "//slowSpeedThresholdTrack") as? SKShapeNode,
               let handle = contentNode.childNode(withName: "//slowSpeedThresholdHandle") as? SKShapeNode {
                if handle.contains(locInContent) || track.contains(locInContent) {
                    updateSlowSpeedThresholdSlider(touchLocation: locInContent, track: track, handle: handle)
                    touchingSlider = true
                }
            }
            
            // Rest Linear Threshold
            if let track = contentNode.childNode(withName: "//restLinTrack") as? SKShapeNode,
               let handle = contentNode.childNode(withName: "//restLinHandle") as? SKShapeNode {
                if handle.contains(locInContent) || track.contains(locInContent) {
                    updateRestLinearSlider(touchLocation: locInContent, track: track, handle: handle)
                    touchingSlider = true
                }
            }
            
            // Rest Angular Threshold
            if let track = contentNode.childNode(withName: "//restAngTrack") as? SKShapeNode,
               let handle = contentNode.childNode(withName: "//restAngHandle") as? SKShapeNode {
                if handle.contains(locInContent) || track.contains(locInContent) {
                    updateRestAngularSlider(touchLocation: locInContent, track: track, handle: handle)
                    touchingSlider = true
                }
            }
            
            // Rest Check Duration
            if let track = contentNode.childNode(withName: "//restCheckTrack") as? SKShapeNode,
               let handle = contentNode.childNode(withName: "//restCheckHandle") as? SKShapeNode {
                if handle.contains(locInContent) || track.contains(locInContent) {
                    updateRestCheckDurationSlider(touchLocation: locInContent, track: track, handle: handle)
                    touchingSlider = true
                }
            }
            
            // Stop Speed Threshold
            if let track = contentNode.childNode(withName: "//stopSpeedTrack") as? SKShapeNode,
               let handle = contentNode.childNode(withName: "//stopSpeedHandle") as? SKShapeNode {
                if handle.contains(locInContent) || track.contains(locInContent) {
                    updateStopSpeedSlider(touchLocation: locInContent, track: track, handle: handle)
                    touchingSlider = true
                }
            }
            
            // Stop Angular Threshold
            if let track = contentNode.childNode(withName: "//stopAngTrack") as? SKShapeNode,
               let handle = contentNode.childNode(withName: "//stopAngHandle") as? SKShapeNode {
                if handle.contains(locInContent) || track.contains(locInContent) {
                    updateStopAngularSlider(touchLocation: locInContent, track: track, handle: handle)
                    touchingSlider = true
                }
            }
            
            // Restitution
            if let track = contentNode.childNode(withName: "//restitutionTrack") as? SKShapeNode,
               let handle = contentNode.childNode(withName: "//restitutionHandle") as? SKShapeNode {
                if handle.contains(locInContent) || track.contains(locInContent) {
                    updateRestitutionSlider(touchLocation: locInContent, track: track, handle: handle)
                    touchingSlider = true
                }
            }
            
            // Check restart button tap (in contentNode)
            if let restart = contentNode.childNode(withName: "//restartGameButton") as? SKShapeNode {
                if restart.contains(locInContent) {
                    // Trigger restart
                    onRestartRequested?()
                    // Hide overlay after action
                    toggleVisibility()
                    return true
                }
            }
            
            // Check reset button tap (still in contentNode)
            if let reset = contentNode.childNode(withName: "//resetProgressButton") as? SKShapeNode {
                if reset.contains(locInContent) {
                    // Trigger reset
                    onResetRequested?()
                    // Hide overlay after action
                    toggleVisibility()
                    return true
                }
            }
            
            // Check HP bars toggle (in contentNode)
            if let hpToggle = contentNode.childNode(withName: "//healthBarsToggle") as? SKShapeNode {
                if hpToggle.contains(locInContent) {
                    healthBarsEnabled.toggle()
                    updateToggleButton(hpToggle, enabled: healthBarsEnabled, title: "Show HP Bars")
                    // Update damage system
                    if let scene = scene as? StarfieldScene {
                        scene.damageSystem?.config.showHealthBars = healthBarsEnabled
                        // Update existing health bars
                        if healthBarsEnabled {
                            scene.damageSystem?.showAllHealthBars()
                        } else {
                            scene.damageSystem?.hideAllHealthBars()
                        }
                    }
                    // Save to UserDefaults
                    saveSetting(SettingsKey.healthBarsEnabled, value: healthBarsEnabled)
                    return true
                }
            }
            
            // Check damage numbers toggle (in contentNode)
            if let dmgToggle = contentNode.childNode(withName: "//damageNumbersToggle") as? SKShapeNode {
                if dmgToggle.contains(locInContent) {
                    damageNumbersEnabled.toggle()
                    updateToggleButton(dmgToggle, enabled: damageNumbersEnabled, title: "Show Damage Numbers")
                    // Update damage system
                    if let scene = scene as? StarfieldScene {
                        scene.damageSystem?.config.showDamageNumbers = damageNumbersEnabled
                    }
                    // Save to UserDefaults
                    saveSetting(SettingsKey.damageNumbersEnabled, value: damageNumbersEnabled)
                    return true
                }
            }
            
            // Check flying accessory test button (in contentNode)
            if let flyingButton = contentNode.childNode(withName: "//testFlyingAccessoryButton") as? SKShapeNode {
                if flyingButton.contains(locInContent) {
                    testFlyingAccessory()
                    return true
                }
            }
            
            // If not touching a control, start scrolling
            if !touchingSlider {
                overlayScrolling = true
                overlayScrollStartY = locInBG.y
                lastOverlayTouchY = locInBG.y
                overlayScrollVelocity = 0
            }
            
            return touchingSlider || bg.contains(locInBG)
        }
        
        return false
    }
    
    func handleTouchMoved(_ touch: UITouch) -> Bool {
        guard let scene = scene else { return false }
        
        // Handle scrolling
        if overlayScrolling, let bg = overlayBackground, let contentNode = overlayContentNode {
            let locInBG = touch.location(in: bg)
            let deltaY = locInBG.y - lastOverlayTouchY
            
            // Update scroll offset
            overlayScrollOffset -= deltaY
            overlayScrollOffset = max(0, min(overlayMaxScrollOffset, overlayScrollOffset))
            
            // Apply scroll offset to content
            contentNode.position.y = overlayScrollOffset
            
            // Track velocity for momentum
            overlayScrollVelocity = -deltaY
            lastOverlayTouchY = locInBG.y
            return true
        }
        
        // Overlay interaction with sliders
        if overlayVisible, let contentNode = overlayContentNode {
            let locInContent = touch.location(in: contentNode)
            
            // Check damage multiplier slider drag
            if let track = contentNode.childNode(withName: "//damageMultiplierTrack") as? SKShapeNode,
               let handle = contentNode.childNode(withName: "//damageMultiplierHandle") as? SKShapeNode {
                if handle.contains(locInContent) || track.contains(locInContent) {
                    updateDamageMultiplierSlider(touchLocation: locInContent, track: track, handle: handle)
                    return true
                }
            }
            
            // Check max impulse slider drag
            if let track = contentNode.childNode(withName: "//maxImpulseTrack") as? SKShapeNode,
               let handle = contentNode.childNode(withName: "//maxImpulseHandle") as? SKShapeNode {
                if handle.contains(locInContent) || track.contains(locInContent) {
                    updateMaxImpulseSlider(touchLocation: locInContent, track: track, handle: handle)
                    return true
                }
            }
            
            // Check 3ball mass slider drag
            if let track = contentNode.childNode(withName: "//threeBallMassTrack") as? SKShapeNode,
               let handle = contentNode.childNode(withName: "//threeBallMassHandle") as? SKShapeNode {
                if handle.contains(locInContent) || track.contains(locInContent) {
                    update3BallMassSlider(touchLocation: locInContent, track: track, handle: handle)
                    return true
                }
            }
            
            // New sliders' touch moved detection:
            if let track = contentNode.childNode(withName: "//maxShotDistanceTrack") as? SKShapeNode,
               let handle = contentNode.childNode(withName: "//maxShotDistanceHandle") as? SKShapeNode {
                if handle.contains(locInContent) || track.contains(locInContent) {
                    updateMaxShotDistanceSlider(touchLocation: locInContent, track: track, handle: handle)
                    return true
                }
            }
            
            if let track = contentNode.childNode(withName: "//powerExponentTrack") as? SKShapeNode,
               let handle = contentNode.childNode(withName: "//powerExponentHandle") as? SKShapeNode {
                if handle.contains(locInContent) || track.contains(locInContent) {
                    updatePowerExponentSlider(touchLocation: locInContent, track: track, handle: handle)
                    return true
                }
            }
            
            if let track = contentNode.childNode(withName: "//fourBallRadiusTrack") as? SKShapeNode,
               let handle = contentNode.childNode(withName: "//fourBallRadiusHandle") as? SKShapeNode {
                if handle.contains(locInContent) || track.contains(locInContent) {
                    update4BallRadiusSlider(touchLocation: locInContent, track: track, handle: handle)
                    return true
                }
            }
            
            // 4-Ball Max Triggers slider drag detection
            if let track = contentNode.childNode(withName: "//fourBallMaxTriggersTrack") as? SKShapeNode,
               let handle = contentNode.childNode(withName: "//fourBallMaxTriggersHandle") as? SKShapeNode {
                if handle.contains(locInContent) || track.contains(locInContent) {
                    update4BallMaxTriggersSlider(at: locInContent)
                    return true
                }
            }
            
            if let track = contentNode.childNode(withName: "//frictionTrack") as? SKShapeNode,
               let handle = contentNode.childNode(withName: "//frictionHandle") as? SKShapeNode {
                if handle.contains(locInContent) || track.contains(locInContent) {
                    updateFrictionSlider(touchLocation: locInContent, track: track, handle: handle)
                    return true
                }
            }
            
            if let track = contentNode.childNode(withName: "//linearDampingTrack") as? SKShapeNode,
               let handle = contentNode.childNode(withName: "//linearDampingHandle") as? SKShapeNode {
                if handle.contains(locInContent) || track.contains(locInContent) {
                    updateLinearDampingSlider(touchLocation: locInContent, track: track, handle: handle)
                    return true
                }
            }
            
            if let track = contentNode.childNode(withName: "//baseAngDampingTrack") as? SKShapeNode,
               let handle = contentNode.childNode(withName: "//baseAngDampingHandle") as? SKShapeNode {
                if handle.contains(locInContent) || track.contains(locInContent) {
                    updateBaseAngDampingSlider(touchLocation: locInContent, track: track, handle: handle)
                    return true
                }
            }
            
            if let track = contentNode.childNode(withName: "//highAngDampingTrack") as? SKShapeNode,
               let handle = contentNode.childNode(withName: "//highAngDampingHandle") as? SKShapeNode {
                if handle.contains(locInContent) || track.contains(locInContent) {
                    updateHighAngDampingSlider(touchLocation: locInContent, track: track, handle: handle)
                    return true
                }
            }
            
            if let track = contentNode.childNode(withName: "//slowSpeedThresholdTrack") as? SKShapeNode,
               let handle = contentNode.childNode(withName: "//slowSpeedThresholdHandle") as? SKShapeNode {
                if handle.contains(locInContent) || track.contains(locInContent) {
                    updateSlowSpeedThresholdSlider(touchLocation: locInContent, track: track, handle: handle)
                    return true
                }
            }
            
            if let track = contentNode.childNode(withName: "//restLinTrack") as? SKShapeNode,
               let handle = contentNode.childNode(withName: "//restLinHandle") as? SKShapeNode {
                if handle.contains(locInContent) || track.contains(locInContent) {
                    updateRestLinearSlider(touchLocation: locInContent, track: track, handle: handle)
                    return true
                }
            }
            
            if let track = contentNode.childNode(withName: "//restAngTrack") as? SKShapeNode,
               let handle = contentNode.childNode(withName: "//restAngHandle") as? SKShapeNode {
                if handle.contains(locInContent) || track.contains(locInContent) {
                    updateRestAngularSlider(touchLocation: locInContent, track: track, handle: handle)
                    return true
                }
            }
            
            if let track = contentNode.childNode(withName: "//restCheckTrack") as? SKShapeNode,
               let handle = contentNode.childNode(withName: "//restCheckHandle") as? SKShapeNode {
                if handle.contains(locInContent) || track.contains(locInContent) {
                    updateRestCheckDurationSlider(touchLocation: locInContent, track: track, handle: handle)
                    return true
                }
            }
            
            if let track = contentNode.childNode(withName: "//stopSpeedTrack") as? SKShapeNode,
               let handle = contentNode.childNode(withName: "//stopSpeedHandle") as? SKShapeNode {
                if handle.contains(locInContent) || track.contains(locInContent) {
                    updateStopSpeedSlider(touchLocation: locInContent, track: track, handle: handle)
                    return true
                }
            }
            
            if let track = contentNode.childNode(withName: "//stopAngTrack") as? SKShapeNode,
               let handle = contentNode.childNode(withName: "//stopAngHandle") as? SKShapeNode {
                if handle.contains(locInContent) || track.contains(locInContent) {
                    updateStopAngularSlider(touchLocation: locInContent, track: track, handle: handle)
                    return true
                }
            }
            
            if let track = contentNode.childNode(withName: "//restitutionTrack") as? SKShapeNode,
               let handle = contentNode.childNode(withName: "//restitutionHandle") as? SKShapeNode {
                if handle.contains(locInContent) || track.contains(locInContent) {
                    updateRestitutionSlider(touchLocation: locInContent, track: track, handle: handle)
                    return true
                }
            }
        }
        
        return false
    }
    
    func handleTouchEnded(_ touch: UITouch) -> Bool {
        // End scrolling
        if overlayScrolling {
            overlayScrolling = false
            return true
        }
        
        return false
    }
    
    private func updateDamageMultiplierSlider(touchLocation: CGPoint, track: SKShapeNode, handle: SKShapeNode) {
        guard let scene = scene as? StarfieldScene else { return }
        guard let contentNode = overlayContentNode else { return }
        
        let trackWidth = track.frame.width
        let trackX = track.position.x
        
        // Calculate relative X position on track
        let relativeX = touchLocation.x - trackX
        let clampedX = max(-trackWidth/2, min(trackWidth/2, relativeX))
        let t = (clampedX + trackWidth/2) / trackWidth
        
        // Map to 1.0-10.0 range
        let minVal: CGFloat = 1.0
        let maxVal: CGFloat = 10.0
        let newValue = minVal + t * (maxVal - minVal)
        
        // Update damage system
        scene.damageSystem?.config.damageMultiplier = newValue
        
        // Save to UserDefaults
        saveSetting(SettingsKey.damageMultiplier, value: Double(newValue))
        
        // Move handle
        let xOffset = -trackWidth/2 + t * trackWidth
        handle.position.x = trackX + xOffset
        
        // Update value label
        if let valueLabel = contentNode.childNode(withName: "//damageMultiplierValue") as? SKLabelNode {
            valueLabel.text = formatDamageMultiplier(newValue)
        }
        
        print("🎚️ Damage Multiplier set to \(String(format: "%.1f", newValue))×")
    }
    
    // MARK: - Private Methods
    private func setOverlayVisible(_ visible: Bool) {
        if visible == overlayVisible { return }
        overlayVisible = visible
        if visible {
            buildOverlay()
            overlayContainer?.alpha = 0
            overlayContainer?.run(SKAction.fadeIn(withDuration: 0.2))
        } else {
            overlayContainer?.run(SKAction.fadeOut(withDuration: 0.2), completion: { [weak self] in
                self?.overlayContainer?.removeFromParent()
                self?.overlayBackdrop?.removeFromParent()
                self?.overlayContainer = nil
                self?.overlayBackdrop = nil
                self?.overlayBackground = nil
                self?.overlayContentNode = nil
            })
        }
    }
    
    private func addBallPreviewSprites(to parent: SKNode, maxWidth: CGFloat, maxHeight: CGFloat) {
        // Ball types to display
        let ballTypes: [(kind: BlockBall.Kind, name: String, color: SKColor, isStriped: Bool, stripeColor: SKColor?)] = [
            (.cue, "Cue", SKColor(white: 1.0, alpha: 1.0), false, nil),
            (.eight, "8-Ball", .black, false, nil),
            (.eleven, "11-Ball", SKColor(white: 1.0, alpha: 1.0), true, .red),
            (.two, "2-Ball", .blue, false, nil),
            (.three, "3-Ball", .red, false, nil),
            (.four, "4-Ball", .purple, false, nil),
            (.five, "5-Ball", .orange, false, nil)
        ]
        
        let spriteSize: CGFloat = 25  // 5x5 blocks at 5pt each
        let spacing: CGFloat = 12
        let labelOffset: CGFloat = 16
        let startY = maxHeight/2 - 50  // Position below title
        
        // Calculate total width needed
        let totalWidth = CGFloat(ballTypes.count) * (spriteSize + spacing) - spacing
        let startX = -totalWidth / 2 + spriteSize / 2
        
        for (index, ballInfo) in ballTypes.enumerated() {
            let xPos = startX + CGFloat(index) * (spriteSize + spacing)
            
            // Create ball sprite texture
            let generator = BallSpriteGenerator()
            let texture: SKTexture
            
            if ballInfo.isStriped {
                // For striped balls, show with spot at center
                texture = generator.generateTexture(
                    fillColor: ballInfo.color,
                    spotPosition: .hidden,  // No spot for striped balls
                    shape: .circle,
                    isStriped: true,
                    stripeColor: ballInfo.stripeColor ?? .white,
                    rotationX: 0,
                    rotationY: 0
                )
            } else {
                // For solid balls, show with spot at center (centerTop position)
                texture = generator.generateTexture(
                    fillColor: ballInfo.color,
                    spotPosition: .centerTop,  // Show spot at center
                    shape: .circle,
                    isStriped: false
                )
            }
            
            // Create container for sprite and label (for easier touch detection)
            let container = SKNode()
            container.name = "ballPreview_\(ballInfo.kind)"
            container.position = CGPoint(x: xPos, y: startY)
            container.zPosition = 1
            
            // Create sprite node
            let sprite = SKSpriteNode(texture: texture)
            sprite.size = CGSize(width: spriteSize, height: spriteSize)
            sprite.position = .zero
            sprite.name = "sprite"
            container.addChild(sprite)
            
            // Add invisible touch area (larger than sprite for easier clicking)
            let touchArea = SKShapeNode(rectOf: CGSize(width: spriteSize + 10, height: spriteSize + 10))
            touchArea.fillColor = .clear
            touchArea.strokeColor = .clear
            touchArea.name = "touchArea"
            container.addChild(touchArea)
            
            parent.addChild(container)
            
            // Add label below sprite
            let label = SKLabelNode(fontNamed: "Courier")
            label.text = ballInfo.name
            label.fontSize = 9
            label.fontColor = SKColor(white: 0.8, alpha: 1.0)
            label.horizontalAlignmentMode = .center
            label.verticalAlignmentMode = .top
            label.position = CGPoint(x: xPos, y: startY - spriteSize/2 - 3)
            label.zPosition = 1
            label.name = "ballLabel_\(ballInfo.kind)"
            parent.addChild(label)
        }
    }
    
    private func handleBallPreviewTap(kindString: String) {
        guard let scene = scene as? StarfieldScene else { return }
        
        // Check if table is visible
        guard let tableContainer = scene.childNode(withName: "BlockTable"), !tableContainer.isHidden else {
            print("🚫 Cannot spawn ball: table is not visible")
            return
        }
        
        // Check if we have felt rect
        guard let feltRect = scene.blockFeltRect else {
            print("🚫 Cannot spawn ball: no felt rect available")
            return
        }
        
        // Parse ball kind from string
        let ballKind: BlockBall.Kind
        switch kindString {
        case "cue":
            ballKind = .cue
        case "eight":
            ballKind = .eight
        case "eleven":
            ballKind = .eleven
        case "two":
            ballKind = .two
        case "three":
            ballKind = .three
        case "four":
            ballKind = .four
        case "five":
            ballKind = .five
        default:
            print("🚫 Unknown ball kind: \(kindString)")
            return
        }
        
        // Find a random spawn point on the felt
        guard let spawnPoint = scene.randomSpawnPoint(minClearance: 30) else {
            print("🚫 Cannot find valid spawn point for ball")
            return
        }
        
        // Create the ball
        let ball = BlockBall(
            kind: ballKind,
            position: spawnPoint,
            in: scene,
            feltRect: feltRect,
            pocketCenters: scene.blockPocketCenters ?? [],
            pocketRadius: scene.blockPocketRadius ?? 0
        )
        
        if ball.parent == nil {
            scene.addChild(ball)
        }
        
        // Register with damage system
        let customHP: CGFloat?
        switch ballKind {
        case .three:
            customHP = 200  // 3-ball gets 200 HP
        case .four:
            customHP = 20   // 4-ball gets 20 HP
        case .two:
            customHP = 20   // 2-ball gets 20 HP
        case .five:
            customHP = 50   // 5-ball gets 50 HP (low HP with flying)
        default:
            customHP = nil  // Use default HP
        }
        
        if let hp = customHP {
            scene.damageSystem?.registerBall(ball, customHP: hp)
        } else {
            scene.damageSystem?.registerBall(ball)
        }
        
        // If spawning a cue ball, add to tracking
        if ballKind == .cue {
            scene.addCueBall(ball)
        }
        
        // Apply physics settings
        scene.applyPhysicsToAllBalls()
        
        print("🎱 Spawned \(ballKind) ball at \(spawnPoint) from overlay tap")
    }
    
    private func buildOverlay() {
        guard let scene = scene else { return }
        
        // Remove existing overlay and clean up
        overlayContainer?.removeFromParent()
        overlayBackdrop?.removeFromParent()
        overlayContainer = nil
        overlayBackdrop = nil
        overlayBackground = nil
        overlayContentNode = nil
        sliderNodes.removeAll()
        
        // Backdrop to darken background and catch touches
        let backdrop = SKShapeNode(rectOf: scene.size)
        backdrop.fillColor = SKColor(white: 0, alpha: 0.4)
        backdrop.strokeColor = .clear
        backdrop.zPosition = 1498
        backdrop.name = "overlayBackdrop"
        backdrop.position = CGPoint(x: scene.size.width/2, y: scene.size.height/2)
        scene.addChild(backdrop)
        overlayBackdrop = backdrop
        
        // Container node for overlay UI
        let container = SKNode()
        container.zPosition = 1500
        container.name = "overlayContainer"
        
        // Background panel - updated size for more space
        let maxWidth = min(scene.size.width - 40, 700)
        let maxHeight = min(scene.size.height - 80, 720)
        let bg = SKShapeNode(rectOf: CGSize(width: maxWidth, height: maxHeight), cornerRadius: 16)
        bg.fillColor = SKColor(white: 0.05, alpha: 0.92)
        bg.strokeColor = SKColor(white: 1.0, alpha: 0.15)
        bg.lineWidth = 2
        bg.position = CGPoint(x: scene.size.width/2, y: scene.size.height/2)
        bg.name = "overlayBackground"
        container.addChild(bg)
        overlayBackground = bg
        
        // Title (fixed at top, not scrollable)
        let title = SKLabelNode(fontNamed: "Courier-Bold")
        title.text = "Options"
        title.fontSize = 18
        title.fontColor = .white
        title.horizontalAlignmentMode = .left
        title.verticalAlignmentMode = .top
        title.position = CGPoint(x: -maxWidth/2 + 16, y: maxHeight/2 - 16)
        title.zPosition = 1
        bg.addChild(title)
        
        // Ball sprite previews (fixed at top, not scrollable)
        addBallPreviewSprites(to: bg, maxWidth: maxWidth, maxHeight: maxHeight)
        
        // Create scrollable content node
        let contentNode = SKNode()
        contentNode.name = "overlayContent"
        
        // Define two columns: Gameplay (left) and Physics (right)
        let columnPadding: CGFloat = 16
        let columnGap: CGFloat = 20
        let columnWidth = (maxWidth - 2 * columnPadding - columnGap) / 2
        let gameplayX: CGFloat = -maxWidth/2 + columnPadding + columnWidth/2
        let physicsX: CGFloat = maxWidth/2 - columnPadding - columnWidth/2
        
        // Start both columns from the top (below ball sprites)
        var yGameplay: CGFloat = maxHeight/2 - 90  // Adjusted to make room for ball previews
        var yPhysics: CGFloat = maxHeight/2 - 90
        
        // Helper function to place sliders
        func place(_ nodeBuilder: (SKNode, CGFloat, CGFloat) -> CGFloat, _ x: CGFloat, _ y: inout CGFloat, _ name: String) {
            let tempParent = SKNode()
            let retY = nodeBuilder(tempParent, columnWidth, y)
            // Reposition all children of tempParent by translating x to column center
            // Need to copy the children array since we're modifying the tree
            let children = Array(tempParent.children)
            for child in children {
                child.removeFromParent()
                child.position.x += x
                contentNode.addChild(child)
            }
            y = retY - 25  // Reduced spacing from 40 to 25
        }
        
        // Add column headers
        let gameplayHeader = SKLabelNode(fontNamed: "Courier-Bold")
        gameplayHeader.text = "GAMEPLAY"
        gameplayHeader.fontSize = 12
        gameplayHeader.fontColor = SKColor(white: 0.7, alpha: 1.0)
        gameplayHeader.horizontalAlignmentMode = .center
        gameplayHeader.verticalAlignmentMode = .top
        gameplayHeader.position = CGPoint(x: gameplayX, y: yGameplay)
        gameplayHeader.zPosition = 1
        contentNode.addChild(gameplayHeader)
        yGameplay -= 20
        
        // Restart Button (blue) - at top of Gameplay column
        let restartButtonWidth: CGFloat = columnWidth - 20
        let restartButtonHeight: CGFloat = 32
        let restartButton = SKShapeNode(rectOf: CGSize(width: restartButtonWidth, height: restartButtonHeight), cornerRadius: 8)
        restartButton.name = "restartGameButton"
        restartButton.fillColor = SKColor(red: 0.2, green: 0.5, blue: 0.9, alpha: 1.0)
        restartButton.strokeColor = SKColor(white: 1.0, alpha: 0.3)
        restartButton.lineWidth = 2
        restartButton.position = CGPoint(x: gameplayX, y: yGameplay - restartButtonHeight/2)
        restartButton.zPosition = 1
        contentNode.addChild(restartButton)

        let restartLabel = SKLabelNode(fontNamed: "Courier-Bold")
        restartLabel.text = "Restart Game"
        restartLabel.fontSize = 13
        restartLabel.fontColor = .white
        restartLabel.verticalAlignmentMode = .center
        restartLabel.horizontalAlignmentMode = .center
        restartLabel.position = .zero
        restartLabel.zPosition = 2
        restartButton.addChild(restartLabel)
        
        yGameplay -= restartButtonHeight + 15  // Space after button
        
        let physicsHeader = SKLabelNode(fontNamed: "Courier-Bold")
        physicsHeader.text = "PHYSICS"
        physicsHeader.fontSize = 12
        physicsHeader.fontColor = SKColor(white: 0.7, alpha: 1.0)
        physicsHeader.horizontalAlignmentMode = .center
        physicsHeader.verticalAlignmentMode = .top
        physicsHeader.position = CGPoint(x: physicsX, y: yPhysics)
        physicsHeader.zPosition = 1
        contentNode.addChild(physicsHeader)
        yPhysics -= 20
        
        // GAMEPLAY COLUMN (Left)
        place({ parent, width, y in self.addDamageMultiplierSliderToNode(parent, width: width, yCursor: y) }, gameplayX, &yGameplay, "dmgMult")
        place({ parent, width, y in self.addMaxImpulseSliderToNode(parent, width: width, yCursor: y) }, gameplayX, &yGameplay, "maxImpulse")
        place({ parent, width, y in self.add3BallMassSliderToNode(parent, width: width, yCursor: y) }, gameplayX, &yGameplay, "3ballMass")
        place({ parent, width, y in self.addMaxShotDistanceSliderToNode(parent, width: width, yCursor: y) }, gameplayX, &yGameplay, "maxShot")
        place({ parent, width, y in self.addPowerExponentSliderToNode(parent, width: width, yCursor: y) }, gameplayX, &yGameplay, "powerExp")
        place({ parent, width, y in self.add4BallDamageRadiusSliderToNode(parent, width: width, yCursor: y) }, gameplayX, &yGameplay, "4ballRadius")
        place({ parent, width, y in self.add4BallMaxTriggersSliderToNode(parent, width: width, yCursor: y) }, gameplayX, &yGameplay, "4ballTriggers")
        
        // PHYSICS COLUMN (Right)
        place({ parent, width, y in self.addFrictionSliderToNode(parent, width: width, yCursor: y) }, physicsX, &yPhysics, "friction")
        place({ parent, width, y in self.addLinearDampingSliderToNode(parent, width: width, yCursor: y) }, physicsX, &yPhysics, "linDamp")
        place({ parent, width, y in self.addRestitutionSliderToNode(parent, width: width, yCursor: y) }, physicsX, &yPhysics, "restitution")
        place({ parent, width, y in self.addBaseAngDampingSliderToNode(parent, width: width, yCursor: y) }, physicsX, &yPhysics, "baseAng")
        place({ parent, width, y in self.addHighAngDampingSliderToNode(parent, width: width, yCursor: y) }, physicsX, &yPhysics, "highAng")
        place({ parent, width, y in self.addSlowSpeedThresholdSliderToNode(parent, width: width, yCursor: y) }, physicsX, &yPhysics, "slowThresh")
        place({ parent, width, y in self.addRestLinearSliderToNode(parent, width: width, yCursor: y) }, physicsX, &yPhysics, "restLin")
        place({ parent, width, y in self.addRestAngularSliderToNode(parent, width: width, yCursor: y) }, physicsX, &yPhysics, "restAng")
        place({ parent, width, y in self.addRestCheckDurationSliderToNode(parent, width: width, yCursor: y) }, physicsX, &yPhysics, "restCheck")
        place({ parent, width, y in self.addStopSpeedSliderToNode(parent, width: width, yCursor: y) }, physicsX, &yPhysics, "stopSpeed")
        place({ parent, width, y in self.addStopAngularSliderToNode(parent, width: width, yCursor: y) }, physicsX, &yPhysics, "stopAng")
        
        // Position Reset Progress button below the lower column lowest Y
        let buttonWidth: CGFloat = maxWidth - 32
        let buttonHeight: CGFloat = 44
        
        let lowestY = min(yGameplay, yPhysics)
        
        // Reset Progress Button (red) - now the only button at bottom
        let resetButtonY = lowestY - 60
        let resetButton = SKShapeNode(rectOf: CGSize(width: buttonWidth, height: buttonHeight), cornerRadius: 10)
        resetButton.name = "resetProgressButton"
        resetButton.fillColor = SKColor(red: 0.9, green: 0.2, blue: 0.2, alpha: 1.0)
        resetButton.strokeColor = SKColor(white: 1.0, alpha: 0.3)
        resetButton.lineWidth = 2
        resetButton.position = CGPoint(x: 0, y: resetButtonY)
        contentNode.addChild(resetButton)

        let resetLabel = SKLabelNode(fontNamed: "Courier-Bold")
        resetLabel.text = "Reset Progress"
        resetLabel.fontSize = 16
        resetLabel.fontColor = .white
        resetLabel.verticalAlignmentMode = .center
        resetLabel.horizontalAlignmentMode = .center
        resetLabel.position = .zero
        resetLabel.zPosition = 2
        resetButton.addChild(resetLabel)
        
        // HP Bars Toggle (in scrollable content)
        let hpToggleY = resetButtonY - 50
        let hpBarsToggle = createToggleButton(
            title: "Show HP Bars",
            position: CGPoint(x: 0, y: hpToggleY),
            name: "healthBarsToggle",
            enabled: healthBarsEnabled
        )
        contentNode.addChild(hpBarsToggle)
        healthBarsToggle = hpBarsToggle
        
        // Damage Numbers Toggle (in scrollable content)
        let dmgToggleY = hpToggleY - 50
        let dmgToggle = createToggleButton(
            title: "Show Damage Numbers",
            position: CGPoint(x: 0, y: dmgToggleY),
            name: "damageNumbersToggle",
            enabled: damageNumbersEnabled
        )
        contentNode.addChild(dmgToggle)
        damageNumbersToggle = dmgToggle
        
        // Test Flying Accessory Button (in scrollable content)
        let flyingButtonY = dmgToggleY - 60
        let flyingButtonWidth: CGFloat = buttonWidth
        let flyingButtonHeight: CGFloat = 44
        let flyingButton = SKShapeNode(rectOf: CGSize(width: flyingButtonWidth, height: flyingButtonHeight), cornerRadius: 10)
        flyingButton.name = "testFlyingAccessoryButton"
        flyingButton.fillColor = SKColor(red: 0.5, green: 0.3, blue: 0.9, alpha: 1.0)
        flyingButton.strokeColor = SKColor(white: 1.0, alpha: 0.3)
        flyingButton.lineWidth = 2
        flyingButton.position = CGPoint(x: 0, y: flyingButtonY)
        contentNode.addChild(flyingButton)

        let flyingLabel = SKLabelNode(fontNamed: "Courier-Bold")
        flyingLabel.text = "🪽 Test Flying Accessory"
        flyingLabel.fontSize = 14
        flyingLabel.fontColor = .white
        flyingLabel.verticalAlignmentMode = .center
        flyingLabel.horizontalAlignmentMode = .center
        flyingLabel.position = .zero
        flyingLabel.zPosition = 2
        flyingButton.addChild(flyingLabel)
        
        // Calculate content height and max scroll offset
        // The lowest element is now the flying accessory button
        let lowestElementY = flyingButtonY - flyingButtonHeight/2
        let contentHeight = abs(lowestElementY) + (maxHeight/2 - 60) + 50 // Add some padding at bottom
        
        let visibleHeight = maxHeight - 80 // Account for title area
        overlayMaxScrollOffset = max(0, contentHeight - visibleHeight)
        overlayScrollOffset = 0
        
        // Create a crop node to mask the scrollable area
        let cropNode = SKCropNode()
        cropNode.position = CGPoint(x: 0, y: -40) // Offset down from title
        let maskSize = CGSize(width: maxWidth, height: visibleHeight)
        let maskNode = SKShapeNode(rectOf: maskSize)
        maskNode.fillColor = .white
        maskNode.strokeColor = .clear
        cropNode.maskNode = maskNode
        cropNode.addChild(contentNode)
        bg.addChild(cropNode)
        
        overlayContentNode = contentNode

        scene.addChild(container)
        overlayContainer = container
        
        print("📜 Overlay built with scrolling support - content height: \(contentHeight), max scroll: \(overlayMaxScrollOffset)")
    }
    
    // MARK: - Added Sliders - addSliderToNode helpers
    
    private func addMaxShotDistanceSliderToNode(_ parent: SKNode, width: CGFloat, yCursor: CGFloat) -> CGFloat {
        guard let scene = scene as? StarfieldScene else { return yCursor }
        var y = yCursor
        let label = SKLabelNode(fontNamed: "Courier")
        label.text = "Max Shot Distance"
        label.fontSize = 14
        label.fontColor = .white
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: -width/2 + 16, y: y)
        parent.addChild(label)
        // Determine current value from a ball
        var current: CGFloat = 156
        for node in scene.children { if let b = node as? BlockBall { current = b.maxShotDistance; break } }
        let valueLabel = SKLabelNode(fontNamed: "Courier-Bold")
        valueLabel.text = formatMaxShotDistance(current)
        valueLabel.fontSize = 14
        valueLabel.fontColor = .white
        valueLabel.horizontalAlignmentMode = .right
        valueLabel.verticalAlignmentMode = .center
        valueLabel.position = CGPoint(x: width/2 - 16, y: y)
        valueLabel.name = "maxShotDistanceValue"
        parent.addChild(valueLabel)
        y -= 15
        let trackWidth: CGFloat = width - 32
        let trackHeight: CGFloat = 4
        let track = SKShapeNode(rectOf: CGSize(width: trackWidth, height: trackHeight), cornerRadius: 2)
        track.fillColor = SKColor(white: 1.0, alpha: 0.3)
        track.strokeColor = .clear
        track.name = "maxShotDistanceTrack"
        track.position = CGPoint(x: 0, y: y)
        parent.addChild(track)
        let handle = SKShapeNode(rectOf: CGSize(width: 20, height: 20), cornerRadius: 4)
        handle.fillColor = .white
        handle.strokeColor = .clear
        handle.name = "maxShotDistanceHandle"
        let minVal: CGFloat = 50
        let maxVal: CGFloat = 300
        let t = (current - minVal) / (maxVal - minVal)
        let xOffset = -trackWidth/2 + t * trackWidth
        handle.position = CGPoint(x: xOffset, y: y)
        parent.addChild(handle)
        return y - 15
    }
    
    private func addPowerExponentSliderToNode(_ parent: SKNode, width: CGFloat, yCursor: CGFloat) -> CGFloat {
        guard let scene = scene as? StarfieldScene else { return yCursor }
        var y = yCursor
        let label = SKLabelNode(fontNamed: "Courier")
        label.text = "Power Curve Exponent"
        label.fontSize = 14
        label.fontColor = .white
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: -width/2 + 16, y: y)
        parent.addChild(label)
        var current: CGFloat = 1.5
        for node in scene.children { if let b = node as? BlockBall { current = b.powerCurveExponent; break } }
        let valueLabel = SKLabelNode(fontNamed: "Courier-Bold")
        valueLabel.text = formatPowerExponent(current)
        valueLabel.fontSize = 14
        valueLabel.fontColor = .white
        valueLabel.horizontalAlignmentMode = .right
        valueLabel.verticalAlignmentMode = .center
        valueLabel.position = CGPoint(x: width/2 - 16, y: y)
        valueLabel.name = "powerExponentValue"
        parent.addChild(valueLabel)
        y -= 15
        let trackWidth: CGFloat = width - 32
        let track = SKShapeNode(rectOf: CGSize(width: trackWidth, height: 4), cornerRadius: 2)
        track.fillColor = SKColor(white: 1.0, alpha: 0.3)
        track.strokeColor = .clear
        track.name = "powerExponentTrack"
        track.position = CGPoint(x: 0, y: y)
        parent.addChild(track)
        let handle = SKShapeNode(rectOf: CGSize(width: 20, height: 20), cornerRadius: 4)
        handle.fillColor = .white
        handle.strokeColor = .clear
        handle.name = "powerExponentHandle"
        let minVal: CGFloat = 0.5
        let maxVal: CGFloat = 3.0
        let t = (current - minVal) / (maxVal - minVal)
        let xOffset = -trackWidth/2 + t * trackWidth
        handle.position = CGPoint(x: xOffset, y: y)
        parent.addChild(handle)
        return y - 15
    }
    
    private func add4BallDamageRadiusSliderToNode(_ parent: SKNode, width: CGFloat, yCursor: CGFloat) -> CGFloat {
        guard let scene = scene as? StarfieldScene else { return yCursor }
        var y = yCursor
        let label = SKLabelNode(fontNamed: "Courier")
        label.text = "4-Ball Pulse Radius"
        label.fontSize = 14
        label.fontColor = .white
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: -width/2 + 16, y: y)
        parent.addChild(label)
        let current = scene.damageSystem?.config.fourBallDamageRadius ?? 18.0
        let valueLabel = SKLabelNode(fontNamed: "Courier-Bold")
        valueLabel.text = format4BallRadius(current)
        valueLabel.fontSize = 14
        valueLabel.fontColor = .white
        valueLabel.horizontalAlignmentMode = .right
        valueLabel.verticalAlignmentMode = .center
        valueLabel.position = CGPoint(x: width/2 - 16, y: y)
        valueLabel.name = "fourBallRadiusValue"
        parent.addChild(valueLabel)
        y -= 15
        let trackWidth: CGFloat = width - 32
        let track = SKShapeNode(rectOf: CGSize(width: trackWidth, height: 4), cornerRadius: 2)
        track.fillColor = SKColor(white: 1.0, alpha: 0.3)
        track.strokeColor = .clear
        track.name = "fourBallRadiusTrack"
        track.position = CGPoint(x: 0, y: y)
        parent.addChild(track)
        let handle = SKShapeNode(rectOf: CGSize(width: 20, height: 20), cornerRadius: 4)
        handle.fillColor = .purple
        handle.strokeColor = SKColor(white: 1.0, alpha: 0.8)
        handle.name = "fourBallRadiusHandle"
        let minVal: CGFloat = 5.0
        let maxVal: CGFloat = 30.0
        let t = (current - minVal) / (maxVal - minVal)
        let xOffset = -trackWidth/2 + t * trackWidth
        handle.position = CGPoint(x: xOffset, y: y)
        parent.addChild(handle)
        return y - 15
    }
    
    private func add4BallMaxTriggersSliderToNode(_ parent: SKNode, width: CGFloat, yCursor: CGFloat) -> CGFloat {
        guard let scene = scene as? StarfieldScene else { return yCursor }
        var y = yCursor
        
        let label = SKLabelNode(fontNamed: "Courier")
        label.text = "4-Ball Max Triggers"
        label.fontSize = 14
        label.fontColor = .white
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: -width/2 + 16, y: y)
        parent.addChild(label)
        
        // Get current value (default 2)
        let current = scene.damageSystem?.config.fourBallMaxTriggers ?? 2
        let valueLabel = SKLabelNode(fontNamed: "Courier-Bold")
        valueLabel.text = "\(current)x"
        valueLabel.fontSize = 14
        valueLabel.fontColor = .white
        valueLabel.horizontalAlignmentMode = .right
        valueLabel.verticalAlignmentMode = .center
        valueLabel.position = CGPoint(x: width/2 - 16, y: y)
        valueLabel.name = "fourBallMaxTriggersValue"
        parent.addChild(valueLabel)
        
        y -= 15
        
        let trackWidth: CGFloat = width - 32
        let track = SKShapeNode(rectOf: CGSize(width: trackWidth, height: 4), cornerRadius: 2)
        track.fillColor = SKColor(white: 1.0, alpha: 0.3)
        track.strokeColor = .clear
        track.name = "fourBallMaxTriggersTrack"
        track.position = CGPoint(x: 0, y: y)
        parent.addChild(track)
        
        let handle = SKShapeNode(rectOf: CGSize(width: 20, height: 20), cornerRadius: 4)
        handle.fillColor = .purple
        handle.strokeColor = SKColor(white: 1.0, alpha: 0.8)
        handle.name = "fourBallMaxTriggersHandle"
        
        // Range is 1-5, snap to integers
        let minVal = 1
        let maxVal = 5
        let t = CGFloat(current - minVal) / CGFloat(maxVal - minVal)
        let xOffset = -trackWidth/2 + t * trackWidth
        handle.position = CGPoint(x: xOffset, y: y)
        parent.addChild(handle)
        
        return y - 15
    }
    
    private func addFrictionSliderToNode(_ parent: SKNode, width: CGFloat, yCursor: CGFloat) -> CGFloat {
        var y = yCursor
        let label = SKLabelNode(fontNamed: "Courier")
        label.text = "Friction"
        label.fontSize = 14
        label.fontColor = .white
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: -width/2 + 16, y: y)
        parent.addChild(label)
        let current: CGFloat = UserDefaults.standard.object(forKey: SettingsKey.friction) != nil ? CGFloat(UserDefaults.standard.double(forKey: SettingsKey.friction)) : 0.12
        let valueLabel = SKLabelNode(fontNamed: "Courier-Bold")
        valueLabel.text = formatFriction(current)
        valueLabel.fontSize = 14
        valueLabel.fontColor = .white
        valueLabel.horizontalAlignmentMode = .right
        valueLabel.verticalAlignmentMode = .center
        valueLabel.position = CGPoint(x: width/2 - 16, y: y)
        valueLabel.name = "frictionValue"
        parent.addChild(valueLabel)
        y -= 15
        let trackWidth: CGFloat = width - 32
        let track = SKShapeNode(rectOf: CGSize(width: trackWidth, height: 4), cornerRadius: 2)
        track.fillColor = SKColor(white: 1.0, alpha: 0.3)
        track.strokeColor = .clear
        track.name = "frictionTrack"
        track.position = CGPoint(x: 0, y: y)
        parent.addChild(track)
        let handle = SKShapeNode(rectOf: CGSize(width: 20, height: 20), cornerRadius: 4)
        handle.fillColor = .white
        handle.strokeColor = .clear
        handle.name = "frictionHandle"
        let minVal: CGFloat = 0.0
        let maxVal: CGFloat = 1.0
        let t = (current - minVal) / (maxVal - minVal)
        let xOffset = -trackWidth/2 + t * trackWidth
        handle.position = CGPoint(x: xOffset, y: y)
        parent.addChild(handle)
        return y - 15
    }
    
    private func addLinearDampingSliderToNode(_ parent: SKNode, width: CGFloat, yCursor: CGFloat) -> CGFloat {
        var y = yCursor
        let label = SKLabelNode(fontNamed: "Courier")
        label.text = "Linear Damping"
        label.fontSize = 14
        label.fontColor = .white
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: -width/2 + 16, y: y)
        parent.addChild(label)
        let current: CGFloat = UserDefaults.standard.object(forKey: SettingsKey.linearDamping) != nil ? CGFloat(UserDefaults.standard.double(forKey: SettingsKey.linearDamping)) : 0.65
        let valueLabel = SKLabelNode(fontNamed: "Courier-Bold")
        valueLabel.text = formatDamping(current)
        valueLabel.fontSize = 14
        valueLabel.fontColor = .white
        valueLabel.horizontalAlignmentMode = .right
        valueLabel.verticalAlignmentMode = .center
        valueLabel.position = CGPoint(x: width/2 - 16, y: y)
        valueLabel.name = "linearDampingValue"
        parent.addChild(valueLabel)
        y -= 15
        let trackWidth: CGFloat = width - 32
        let track = SKShapeNode(rectOf: CGSize(width: trackWidth, height: 4), cornerRadius: 2)
        track.fillColor = SKColor(white: 1.0, alpha: 0.3)
        track.strokeColor = .clear
        track.name = "linearDampingTrack"
        track.position = CGPoint(x: 0, y: y)
        parent.addChild(track)
        let handle = SKShapeNode(rectOf: CGSize(width: 20, height: 20), cornerRadius: 4)
        handle.fillColor = .white
        handle.strokeColor = .clear
        handle.name = "linearDampingHandle"
        let minVal: CGFloat = 0.0
        let maxVal: CGFloat = 2.0
        let t = (current - minVal) / (maxVal - minVal)
        let xOffset = -trackWidth/2 + t * trackWidth
        handle.position = CGPoint(x: xOffset, y: y)
        parent.addChild(handle)
        return y - 15
    }
    
    private func addRestitutionSliderToNode(_ parent: SKNode, width: CGFloat, yCursor: CGFloat) -> CGFloat {
        var y = yCursor
        let label = SKLabelNode(fontNamed: "Courier")
        label.text = "Restitution"
        label.fontSize = 14
        label.fontColor = .white
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: -width/2 + 16, y: y)
        parent.addChild(label)
        let current: CGFloat = UserDefaults.standard.object(forKey: SettingsKey.restitution) != nil ? CGFloat(UserDefaults.standard.double(forKey: SettingsKey.restitution)) : 0.85
        let valueLabel = SKLabelNode(fontNamed: "Courier-Bold")
        valueLabel.text = formatRestitution(current)
        valueLabel.fontSize = 14
        valueLabel.fontColor = .white
        valueLabel.horizontalAlignmentMode = .right
        valueLabel.verticalAlignmentMode = .center
        valueLabel.position = CGPoint(x: width/2 - 16, y: y)
        valueLabel.name = "restitutionValue"
        parent.addChild(valueLabel)
        y -= 15
        let trackWidth: CGFloat = width - 32
        let track = SKShapeNode(rectOf: CGSize(width: trackWidth, height: 4), cornerRadius: 2)
        track.fillColor = SKColor(white: 1.0, alpha: 0.3)
        track.strokeColor = .clear
        track.name = "restitutionTrack"
        track.position = CGPoint(x: 0, y: y)
        parent.addChild(track)
        let handle = SKShapeNode(rectOf: CGSize(width: 20, height: 20), cornerRadius: 4)
        handle.fillColor = .white
        handle.strokeColor = .clear
        handle.name = "restitutionHandle"
        let minVal: CGFloat = 0.0
        let maxVal: CGFloat = 1.0
        let t = (current - minVal) / (maxVal - minVal)
        let xOffset = -trackWidth/2 + t * trackWidth
        handle.position = CGPoint(x: xOffset, y: y)
        parent.addChild(handle)
        return y - 15
    }
    
    private func addBaseAngDampingSliderToNode(_ parent: SKNode, width: CGFloat, yCursor: CGFloat) -> CGFloat {
        var y = yCursor
        let label = SKLabelNode(fontNamed: "Courier")
        label.text = "Base Angular Damping"
        label.fontSize = 14
        label.fontColor = .white
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: -width/2 + 16, y: y)
        parent.addChild(label)
        let current: CGFloat = UserDefaults.standard.object(forKey: SettingsKey.baseAngularDamping) != nil ? CGFloat(UserDefaults.standard.double(forKey: SettingsKey.baseAngularDamping)) : 1.8
        let valueLabel = SKLabelNode(fontNamed: "Courier-Bold")
        valueLabel.text = formatDamping(current)
        valueLabel.fontSize = 14
        valueLabel.fontColor = .white
        valueLabel.horizontalAlignmentMode = .right
        valueLabel.verticalAlignmentMode = .center
        valueLabel.position = CGPoint(x: width/2 - 16, y: y)
        valueLabel.name = "baseAngDampingValue"
        parent.addChild(valueLabel)
        y -= 15
        let trackWidth: CGFloat = width - 32
        let track = SKShapeNode(rectOf: CGSize(width: trackWidth, height: 4), cornerRadius: 2)
        track.fillColor = SKColor(white: 1.0, alpha: 0.3)
        track.strokeColor = .clear
        track.name = "baseAngDampingTrack"
        track.position = CGPoint(x: 0, y: y)
        parent.addChild(track)
        let handle = SKShapeNode(rectOf: CGSize(width: 20, height: 20), cornerRadius: 4)
        handle.fillColor = .white
        handle.strokeColor = .clear
        handle.name = "baseAngDampingHandle"
        let minVal: CGFloat = 0.0
        let maxVal: CGFloat = 5.0
        let t = (current - minVal) / (maxVal - minVal)
        let xOffset = -trackWidth/2 + t * trackWidth
        handle.position = CGPoint(x: xOffset, y: y)
        parent.addChild(handle)
        return y - 15
    }
    
    private func addHighAngDampingSliderToNode(_ parent: SKNode, width: CGFloat, yCursor: CGFloat) -> CGFloat {
        var y = yCursor
        let label = SKLabelNode(fontNamed: "Courier")
        label.text = "High Angular Damping"
        label.fontSize = 14
        label.fontColor = .white
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: -width/2 + 16, y: y)
        parent.addChild(label)
        let current: CGFloat = UserDefaults.standard.object(forKey: SettingsKey.highAngularDamping) != nil ? CGFloat(UserDefaults.standard.double(forKey: SettingsKey.highAngularDamping)) : 8.0
        let valueLabel = SKLabelNode(fontNamed: "Courier-Bold")
        valueLabel.text = formatDamping(current)
        valueLabel.fontSize = 14
        valueLabel.fontColor = .white
        valueLabel.horizontalAlignmentMode = .right
        valueLabel.verticalAlignmentMode = .center
        valueLabel.position = CGPoint(x: width/2 - 16, y: y)
        valueLabel.name = "highAngDampingValue"
        parent.addChild(valueLabel)
        y -= 15
        let trackWidth: CGFloat = width - 32
        let track = SKShapeNode(rectOf: CGSize(width: trackWidth, height: 4), cornerRadius: 2)
        track.fillColor = SKColor(white: 1.0, alpha: 0.3)
        track.strokeColor = .clear
        track.name = "highAngDampingTrack"
        track.position = CGPoint(x: 0, y: y)
        parent.addChild(track)
        let handle = SKShapeNode(rectOf: CGSize(width: 20, height: 20), cornerRadius: 4)
        handle.fillColor = .white
        handle.strokeColor = .clear
        handle.name = "highAngDampingHandle"
        let minVal: CGFloat = 0.0
        let maxVal: CGFloat = 10.0
        let t = (current - minVal) / (maxVal - minVal)
        let xOffset = -trackWidth/2 + t * trackWidth
        handle.position = CGPoint(x: xOffset, y: y)
        parent.addChild(handle)
        return y - 15
    }
    
    private func addSlowSpeedThresholdSliderToNode(_ parent: SKNode, width: CGFloat, yCursor: CGFloat) -> CGFloat {
        var y = yCursor
        let label = SKLabelNode(fontNamed: "Courier")
        label.text = "Slow Speed Threshold"
        label.fontSize = 14
        label.fontColor = .white
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: -width/2 + 16, y: y)
        parent.addChild(label)
        let current: CGFloat = UserDefaults.standard.object(forKey: SettingsKey.slowSpeedThreshold) != nil ? CGFloat(UserDefaults.standard.double(forKey: SettingsKey.slowSpeedThreshold)) : 100.0
        let valueLabel = SKLabelNode(fontNamed: "Courier-Bold")
        valueLabel.text = formatSpeed(current)
        valueLabel.fontSize = 14
        valueLabel.fontColor = .white
        valueLabel.horizontalAlignmentMode = .right
        valueLabel.verticalAlignmentMode = .center
        valueLabel.position = CGPoint(x: width/2 - 16, y: y)
        valueLabel.name = "slowSpeedThresholdValue"
        parent.addChild(valueLabel)
        y -= 15
        let trackWidth: CGFloat = width - 32
        let track = SKShapeNode(rectOf: CGSize(width: trackWidth, height: 4), cornerRadius: 2)
        track.fillColor = SKColor(white: 1.0, alpha: 0.3)
        track.strokeColor = .clear
        track.name = "slowSpeedThresholdTrack"
        track.position = CGPoint(x: 0, y: y)
        parent.addChild(track)
        let handle = SKShapeNode(rectOf: CGSize(width: 20, height: 20), cornerRadius: 4)
        handle.fillColor = .white
        handle.strokeColor = .clear
        handle.name = "slowSpeedThresholdHandle"
        let minVal: CGFloat = 0.0
        let maxVal: CGFloat = 200.0
        let t = (current - minVal) / (maxVal - minVal)
        let xOffset = -trackWidth/2 + t * trackWidth
        handle.position = CGPoint(x: xOffset, y: y)
        parent.addChild(handle)
        return y - 15
    }
    
    private func addRestLinearSliderToNode(_ parent: SKNode, width: CGFloat, yCursor: CGFloat) -> CGFloat {
        var y = yCursor
        let label = SKLabelNode(fontNamed: "Courier")
        label.text = "Rest Linear Threshold"
        label.fontSize = 14
        label.fontColor = .white
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: -width/2 + 16, y: y)
        parent.addChild(label)
        let current: CGFloat = UserDefaults.standard.object(forKey: SettingsKey.restLinearThreshold) != nil ? CGFloat(UserDefaults.standard.double(forKey: SettingsKey.restLinearThreshold)) : 5.0
        let valueLabel = SKLabelNode(fontNamed: "Courier-Bold")
        valueLabel.text = formatSpeed(current)
        valueLabel.fontSize = 14
        valueLabel.fontColor = .white
        valueLabel.horizontalAlignmentMode = .right
        valueLabel.verticalAlignmentMode = .center
        valueLabel.position = CGPoint(x: width/2 - 16, y: y)
        valueLabel.name = "restLinValue"
        parent.addChild(valueLabel)
        y -= 15
        let trackWidth: CGFloat = width - 32
        let track = SKShapeNode(rectOf: CGSize(width: trackWidth, height: 4), cornerRadius: 2)
        track.fillColor = SKColor(white: 1.0, alpha: 0.3)
        track.strokeColor = .clear
        track.name = "restLinTrack"
        track.position = CGPoint(x: 0, y: y)
        parent.addChild(track)
        let handle = SKShapeNode(rectOf: CGSize(width: 20, height: 20), cornerRadius: 4)
        handle.fillColor = .white
        handle.strokeColor = .clear
        handle.name = "restLinHandle"
        let minVal: CGFloat = 0.0
        let maxVal: CGFloat = 20.0
        let t = (current - minVal) / (maxVal - minVal)
        let xOffset = -trackWidth/2 + t * trackWidth
        handle.position = CGPoint(x: xOffset, y: y)
        parent.addChild(handle)
        return y - 15
    }
    
    private func addRestAngularSliderToNode(_ parent: SKNode, width: CGFloat, yCursor: CGFloat) -> CGFloat {
        var y = yCursor
        let label = SKLabelNode(fontNamed: "Courier")
        label.text = "Rest Angular Threshold"
        label.fontSize = 14
        label.fontColor = .white
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: -width/2 + 16, y: y)
        parent.addChild(label)
        let current: CGFloat = UserDefaults.standard.object(forKey: SettingsKey.restAngularThreshold) != nil ? CGFloat(UserDefaults.standard.double(forKey: SettingsKey.restAngularThreshold)) : 0.5
        let valueLabel = SKLabelNode(fontNamed: "Courier-Bold")
        valueLabel.text = formatDamping(current)
        valueLabel.fontSize = 14
        valueLabel.fontColor = .white
        valueLabel.horizontalAlignmentMode = .right
        valueLabel.verticalAlignmentMode = .center
        valueLabel.position = CGPoint(x: width/2 - 16, y: y)
        valueLabel.name = "restAngValue"
        parent.addChild(valueLabel)
        y -= 15
        let trackWidth: CGFloat = width - 32
        let track = SKShapeNode(rectOf: CGSize(width: trackWidth, height: 4), cornerRadius: 2)
        track.fillColor = SKColor(white: 1.0, alpha: 0.3)
        track.strokeColor = .clear
        track.name = "restAngTrack"
        track.position = CGPoint(x: 0, y: y)
        parent.addChild(track)
        let handle = SKShapeNode(rectOf: CGSize(width: 20, height: 20), cornerRadius: 4)
        handle.fillColor = .white
        handle.strokeColor = .clear
        handle.name = "restAngHandle"
        let minVal: CGFloat = 0.0
        let maxVal: CGFloat = 5.0
        let t = (current - minVal) / (maxVal - minVal)
        let xOffset = -trackWidth/2 + t * trackWidth
        handle.position = CGPoint(x: xOffset, y: y)
        parent.addChild(handle)
        return y - 15
    }
    
    private func addRestCheckDurationSliderToNode(_ parent: SKNode, width: CGFloat, yCursor: CGFloat) -> CGFloat {
        var y = yCursor
        let label = SKLabelNode(fontNamed: "Courier")
        label.text = "Rest Check Duration"
        label.fontSize = 14
        label.fontColor = .white
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: -width/2 + 16, y: y)
        parent.addChild(label)
        let current: CGFloat = UserDefaults.standard.object(forKey: SettingsKey.restCheckDuration) != nil ? CGFloat(UserDefaults.standard.double(forKey: SettingsKey.restCheckDuration)) : 0.5
        let valueLabel = SKLabelNode(fontNamed: "Courier-Bold")
        valueLabel.text = formatDuration(current)
        valueLabel.fontSize = 14
        valueLabel.fontColor = .white
        valueLabel.horizontalAlignmentMode = .right
        valueLabel.verticalAlignmentMode = .center
        valueLabel.position = CGPoint(x: width/2 - 16, y: y)
        valueLabel.name = "restCheckValue"
        parent.addChild(valueLabel)
        y -= 15
        let trackWidth: CGFloat = width - 32
        let track = SKShapeNode(rectOf: CGSize(width: trackWidth, height: 4), cornerRadius: 2)
        track.fillColor = SKColor(white: 1.0, alpha: 0.3)
        track.strokeColor = .clear
        track.name = "restCheckTrack"
        track.position = CGPoint(x: 0, y: y)
        parent.addChild(track)
        let handle = SKShapeNode(rectOf: CGSize(width: 20, height: 20), cornerRadius: 4)
        handle.fillColor = .white
        handle.strokeColor = .clear
        handle.name = "restCheckHandle"
        let minVal: CGFloat = 0.0
        let maxVal: CGFloat = 2.0
        let t = (current - minVal) / (maxVal - minVal)
        let xOffset = -trackWidth/2 + t * trackWidth
        handle.position = CGPoint(x: xOffset, y: y)
        parent.addChild(handle)
        return y - 15
    }
    
    private func addStopSpeedSliderToNode(_ parent: SKNode, width: CGFloat, yCursor: CGFloat) -> CGFloat {
        var y = yCursor
        let label = SKLabelNode(fontNamed: "Courier")
        label.text = "Stop Speed Threshold"
        label.fontSize = 14
        label.fontColor = .white
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: -width/2 + 16, y: y)
        parent.addChild(label)
        let current: CGFloat = UserDefaults.standard.object(forKey: SettingsKey.stopSpeedThreshold) != nil ? CGFloat(UserDefaults.standard.double(forKey: SettingsKey.stopSpeedThreshold)) : 12.0
        let valueLabel = SKLabelNode(fontNamed: "Courier-Bold")
        valueLabel.text = formatSpeed(current)
        valueLabel.fontSize = 14
        valueLabel.fontColor = .white
        valueLabel.horizontalAlignmentMode = .right
        valueLabel.verticalAlignmentMode = .center
        valueLabel.position = CGPoint(x: width/2 - 16, y: y)
        valueLabel.name = "stopSpeedValue"
        parent.addChild(valueLabel)
        y -= 15
        let trackWidth: CGFloat = width - 32
        let track = SKShapeNode(rectOf: CGSize(width: trackWidth, height: 4), cornerRadius: 2)
        track.fillColor = SKColor(white: 1.0, alpha: 0.3)
        track.strokeColor = .clear
        track.name = "stopSpeedTrack"
        track.position = CGPoint(x: 0, y: y)
        parent.addChild(track)
        let handle = SKShapeNode(rectOf: CGSize(width: 20, height: 20), cornerRadius: 4)
        handle.fillColor = .white
        handle.strokeColor = .clear
        handle.name = "stopSpeedHandle"
        let minVal: CGFloat = 0.0
        let maxVal: CGFloat = 50.0
        let t = (current - minVal) / (maxVal - minVal)
        let xOffset = -trackWidth/2 + t * trackWidth
        handle.position = CGPoint(x: xOffset, y: y)
        parent.addChild(handle)
        return y - 15
    }
    
    private func addStopAngularSliderToNode(_ parent: SKNode, width: CGFloat, yCursor: CGFloat) -> CGFloat {
        var y = yCursor
        let label = SKLabelNode(fontNamed: "Courier")
        label.text = "Stop Angular Threshold"
        label.fontSize = 14
        label.fontColor = .white
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: -width/2 + 16, y: y)
        parent.addChild(label)
        let current: CGFloat = UserDefaults.standard.object(forKey: SettingsKey.stopAngularThreshold) != nil ? CGFloat(UserDefaults.standard.double(forKey: SettingsKey.stopAngularThreshold)) : 0.8
        let valueLabel = SKLabelNode(fontNamed: "Courier-Bold")
        valueLabel.text = formatDamping(current)
        valueLabel.fontSize = 14
        valueLabel.fontColor = .white
        valueLabel.horizontalAlignmentMode = .right
        valueLabel.verticalAlignmentMode = .center
        valueLabel.position = CGPoint(x: width/2 - 16, y: y)
        valueLabel.name = "stopAngValue"
        parent.addChild(valueLabel)
        y -= 15
        let trackWidth: CGFloat = width - 32
        let track = SKShapeNode(rectOf: CGSize(width: trackWidth, height: 4), cornerRadius: 2)
        track.fillColor = SKColor(white: 1.0, alpha: 0.3)
        track.strokeColor = .clear
        track.name = "stopAngTrack"
        track.position = CGPoint(x: 0, y: y)
        parent.addChild(track)
        let handle = SKShapeNode(rectOf: CGSize(width: 20, height: 20), cornerRadius: 4)
        handle.fillColor = .white
        handle.strokeColor = .clear
        handle.name = "stopAngHandle"
        let minVal: CGFloat = 0.0
        let maxVal: CGFloat = 5.0
        let t = (current - minVal) / (maxVal - minVal)
        let xOffset = -trackWidth/2 + t * trackWidth
        handle.position = CGPoint(x: xOffset, y: y)
        parent.addChild(handle)
        return y - 15
    }
    
    // MARK: - Added Sliders - update methods
    
    private func updateMaxShotDistanceSlider(touchLocation: CGPoint, track: SKShapeNode, handle: SKShapeNode) {
        guard let scene = scene as? StarfieldScene else { return }
        guard let contentNode = overlayContentNode else { return }
        let trackWidth = track.frame.width
        let trackX = track.position.x
        let relativeX = touchLocation.x - trackX
        let clampedX = max(-trackWidth/2, min(trackWidth/2, relativeX))
        let t = (clampedX + trackWidth/2) / trackWidth
        let minVal: CGFloat = 50
        let maxVal: CGFloat = 300
        let newValue = minVal + t * (maxVal - minVal)
        for node in scene.children { if let b = node as? BlockBall { b.setShootingTuning(maxDistance: newValue, maxPower: nil, powerExponent: nil) } }
        saveSetting(SettingsKey.maxShotDistance, value: Double(newValue))
        handle.position.x = trackX + (-trackWidth/2 + t * trackWidth)
        if let valueLabel = contentNode.childNode(withName: "//maxShotDistanceValue") as? SKLabelNode { valueLabel.text = formatMaxShotDistance(newValue) }
    }
    
    private func updatePowerExponentSlider(touchLocation: CGPoint, track: SKShapeNode, handle: SKShapeNode) {
        guard let scene = scene as? StarfieldScene else { return }
        guard let contentNode = overlayContentNode else { return }
        let trackWidth = track.frame.width
        let trackX = track.position.x
        let relativeX = touchLocation.x - trackX
        let clampedX = max(-trackWidth/2, min(trackWidth/2, relativeX))
        let t = (clampedX + trackWidth/2) / trackWidth
        let minVal: CGFloat = 0.5
        let maxVal: CGFloat = 3.0
        let newValue = minVal + t * (maxVal - minVal)
        for node in scene.children { if let b = node as? BlockBall { b.setShootingTuning(maxDistance: nil, maxPower: nil, powerExponent: newValue) } }
        saveSetting(SettingsKey.powerExponent, value: Double(newValue))
        handle.position.x = trackX + (-trackWidth/2 + t * trackWidth)
        if let valueLabel = contentNode.childNode(withName: "//powerExponentValue") as? SKLabelNode { valueLabel.text = formatPowerExponent(newValue) }
    }
    
    private func update4BallRadiusSlider(touchLocation: CGPoint, track: SKShapeNode, handle: SKShapeNode) {
        guard let scene = scene as? StarfieldScene else { return }
        guard let contentNode = overlayContentNode else { return }
        let trackWidth = track.frame.width
        let trackX = track.position.x
        let relativeX = touchLocation.x - trackX
        let clampedX = max(-trackWidth/2, min(trackWidth/2, relativeX))
        let t = (clampedX + trackWidth/2) / trackWidth
        let minVal: CGFloat = 5.0
        let maxVal: CGFloat = 30.0
        let newValue = minVal + t * (maxVal - minVal)
        scene.damageSystem?.config.fourBallDamageRadius = newValue
        saveSetting(SettingsKey.fourBallDamageRadius, value: Double(newValue))
        handle.position.x = trackX + (-trackWidth/2 + t * trackWidth)
        if let valueLabel = contentNode.childNode(withName: "//fourBallRadiusValue") as? SKLabelNode { valueLabel.text = format4BallRadius(newValue) }
    }
    
    private func updateFrictionSlider(touchLocation: CGPoint, track: SKShapeNode, handle: SKShapeNode) {
        guard let scene = scene as? StarfieldScene else { return }
        guard let contentNode = overlayContentNode else { return }
        let trackWidth = track.frame.width
        let trackX = track.position.x
        let relativeX = touchLocation.x - trackX
        let clampedX = max(-trackWidth/2, min(trackWidth/2, relativeX))
        let t = (clampedX + trackWidth/2) / trackWidth
        let minVal: CGFloat = 0.0
        let maxVal: CGFloat = 1.0
        let newValue = minVal + t * (maxVal - minVal)
        for node in scene.children { if let b = node as? BlockBall { b.applyPhysicsCoefficients(friction: newValue, linearDamping: nil, angularDamping: nil, restitution: nil) } }
        saveSetting(SettingsKey.friction, value: Double(newValue))
        handle.position.x = trackX + (-trackWidth/2 + t * trackWidth)
        if let valueLabel = contentNode.childNode(withName: "//frictionValue") as? SKLabelNode { valueLabel.text = formatFriction(newValue) }
    }
    
    private func updateLinearDampingSlider(touchLocation: CGPoint, track: SKShapeNode, handle: SKShapeNode) {
        guard let scene = scene as? StarfieldScene else { return }
        guard let contentNode = overlayContentNode else { return }
        let trackWidth = track.frame.width
        let trackX = track.position.x
        let relativeX = touchLocation.x - trackX
        let clampedX = max(-trackWidth/2, min(trackWidth/2, relativeX))
        let t = (clampedX + trackWidth/2) / trackWidth
        let minVal: CGFloat = 0.0
        let maxVal: CGFloat = 2.0
        let newValue = minVal + t * (maxVal - minVal)
        for node in scene.children { if let b = node as? BlockBall { b.applyPhysicsCoefficients(friction: nil, linearDamping: newValue, angularDamping: nil, restitution: nil) } }
        saveSetting(SettingsKey.linearDamping, value: Double(newValue))
        handle.position.x = trackX + (-trackWidth/2 + t * trackWidth)
        if let valueLabel = contentNode.childNode(withName: "//linearDampingValue") as? SKLabelNode { valueLabel.text = formatDamping(newValue) }
    }
    
    private func updateRestitutionSlider(touchLocation: CGPoint, track: SKShapeNode, handle: SKShapeNode) {
        guard let scene = scene as? StarfieldScene else { return }
        guard let contentNode = overlayContentNode else { return }
        let trackWidth = track.frame.width
        let trackX = track.position.x
        let relativeX = touchLocation.x - trackX
        let clampedX = max(-trackWidth/2, min(trackWidth/2, relativeX))
        let t = (clampedX + trackWidth/2) / trackWidth
        let minVal: CGFloat = 0.0
        let maxVal: CGFloat = 1.0
        let newValue = minVal + t * (maxVal - minVal)
        for node in scene.children { if let b = node as? BlockBall { b.applyPhysicsCoefficients(friction: nil, linearDamping: nil, angularDamping: nil, restitution: newValue) } }
        saveSetting(SettingsKey.restitution, value: Double(newValue))
        handle.position.x = trackX + (-trackWidth/2 + t * trackWidth)
        if let valueLabel = contentNode.childNode(withName: "//restitutionValue") as? SKLabelNode { valueLabel.text = formatRestitution(newValue) }
    }
    
    private func updateBaseAngDampingSlider(touchLocation: CGPoint, track: SKShapeNode, handle: SKShapeNode) {
        guard let scene = scene as? StarfieldScene else { return }
        guard let contentNode = overlayContentNode else { return }
        let trackWidth = track.frame.width
        let trackX = track.position.x
        let relativeX = touchLocation.x - trackX
        let clampedX = max(-trackWidth/2, min(trackWidth/2, relativeX))
        let t = (clampedX + trackWidth/2) / trackWidth
        let minVal: CGFloat = 0.0
        let maxVal: CGFloat = 5.0
        let newValue = minVal + t * (maxVal - minVal)
        for node in scene.children { if let b = node as? BlockBall { b.baseAngularDamping = newValue } }
        saveSetting(SettingsKey.baseAngularDamping, value: Double(newValue))
        handle.position.x = trackX + (-trackWidth/2 + t * trackWidth)
        if let valueLabel = contentNode.childNode(withName: "//baseAngDampingValue") as? SKLabelNode { valueLabel.text = formatDamping(newValue) }
    }
    
    private func updateHighAngDampingSlider(touchLocation: CGPoint, track: SKShapeNode, handle: SKShapeNode) {
        guard let scene = scene as? StarfieldScene else { return }
        guard let contentNode = overlayContentNode else { return }
        let trackWidth = track.frame.width
        let trackX = track.position.x
        let relativeX = touchLocation.x - trackX
        let clampedX = max(-trackWidth/2, min(trackWidth/2, relativeX))
        let t = (clampedX + trackWidth/2) / trackWidth
        let minVal: CGFloat = 0.0
        let maxVal: CGFloat = 10.0
        let newValue = minVal + t * (maxVal - minVal)
        for node in scene.children { if let b = node as? BlockBall { b.highAngularDamping = newValue } }
        saveSetting(SettingsKey.highAngularDamping, value: Double(newValue))
        handle.position.x = trackX + (-trackWidth/2 + t * trackWidth)
        if let valueLabel = contentNode.childNode(withName: "//highAngDampingValue") as? SKLabelNode { valueLabel.text = formatDamping(newValue) }
    }
    
    private func updateSlowSpeedThresholdSlider(touchLocation: CGPoint, track: SKShapeNode, handle: SKShapeNode) {
        guard let scene = scene as? StarfieldScene else { return }
        guard let contentNode = overlayContentNode else { return }
        let trackWidth = track.frame.width
        let trackX = track.position.x
        let relativeX = touchLocation.x - trackX
        let clampedX = max(-trackWidth/2, min(trackWidth/2, relativeX))
        let t = (clampedX + trackWidth/2) / trackWidth
        let minVal: CGFloat = 0.0
        let maxVal: CGFloat = 200.0
        let newValue = minVal + t * (maxVal - minVal)
        for node in scene.children { if let b = node as? BlockBall { b.slowSpeedThreshold = newValue } }
        saveSetting(SettingsKey.slowSpeedThreshold, value: Double(newValue))
        handle.position.x = trackX + (-trackWidth/2 + t * trackWidth)
        if let valueLabel = contentNode.childNode(withName: "//slowSpeedThresholdValue") as? SKLabelNode { valueLabel.text = formatSpeed(newValue) }
    }
    
    private func updateRestLinearSlider(touchLocation: CGPoint, track: SKShapeNode, handle: SKShapeNode) {
        guard let scene = scene as? StarfieldScene else { return }
        guard let contentNode = overlayContentNode else { return }
        let trackWidth = track.frame.width
        let trackX = track.position.x
        let relativeX = touchLocation.x - trackX
        let clampedX = max(-trackWidth/2, min(trackWidth/2, relativeX))
        let t = (clampedX + trackWidth/2) / trackWidth
        let minVal: CGFloat = 0.0
        let maxVal: CGFloat = 20.0
        let newValue = minVal + t * (maxVal - minVal)
        for node in scene.children { if let b = node as? BlockBall { b.restLinearSpeedThreshold = newValue } }
        saveSetting(SettingsKey.restLinearThreshold, value: Double(newValue))
        handle.position.x = trackX + (-trackWidth/2 + t * trackWidth)
        if let valueLabel = contentNode.childNode(withName: "//restLinValue") as? SKLabelNode { valueLabel.text = formatSpeed(newValue) }
    }
    
    private func updateRestAngularSlider(touchLocation: CGPoint, track: SKShapeNode, handle: SKShapeNode) {
        guard let scene = scene as? StarfieldScene else { return }
        guard let contentNode = overlayContentNode else { return }
        let trackWidth = track.frame.width
        let trackX = track.position.x
        let relativeX = touchLocation.x - trackX
        let clampedX = max(-trackWidth/2, min(trackWidth/2, relativeX))
        let t = (clampedX + trackWidth/2) / trackWidth
        let minVal: CGFloat = 0.0
        let maxVal: CGFloat = 5.0
        let newValue = minVal + t * (maxVal - minVal)
        for node in scene.children { if let b = node as? BlockBall { b.restAngularSpeedThreshold = newValue } }
        saveSetting(SettingsKey.restAngularThreshold, value: Double(newValue))
        handle.position.x = trackX + (-trackWidth/2 + t * trackWidth)
        if let valueLabel = contentNode.childNode(withName: "//restAngValue") as? SKLabelNode { valueLabel.text = formatDamping(newValue) }
    }
    
    private func updateRestCheckDurationSlider(touchLocation: CGPoint, track: SKShapeNode, handle: SKShapeNode) {
        guard let scene = scene as? StarfieldScene else { return }
        guard let contentNode = overlayContentNode else { return }
        let trackWidth = track.frame.width
        let trackX = track.position.x
        let relativeX = touchLocation.x - trackX
        let clampedX = max(-trackWidth/2, min(trackWidth/2, relativeX))
        let t = (clampedX + trackWidth/2) / trackWidth
        let minVal: CGFloat = 0.0
        let maxVal: CGFloat = 2.0
        let newValue = minVal + t * (maxVal - minVal)
        for node in scene.children { if let b = node as? BlockBall { b.restCheckDuration = newValue } }
        saveSetting(SettingsKey.restCheckDuration, value: Double(newValue))
        handle.position.x = trackX + (-trackWidth/2 + t * trackWidth)
        if let valueLabel = contentNode.childNode(withName: "//restCheckValue") as? SKLabelNode { valueLabel.text = formatDuration(newValue) }
    }
    
    private func updateStopSpeedSlider(touchLocation: CGPoint, track: SKShapeNode, handle: SKShapeNode) {
        guard let scene = scene as? StarfieldScene else { return }
        guard let contentNode = overlayContentNode else { return }
        let trackWidth = track.frame.width
        let trackX = track.position.x
        let relativeX = touchLocation.x - trackX
        let clampedX = max(-trackWidth/2, min(trackWidth/2, relativeX))
        let t = (clampedX + trackWidth/2) / trackWidth
        let minVal: CGFloat = 0.0
        let maxVal: CGFloat = 50.0
        let newValue = minVal + t * (maxVal - minVal)
        for node in scene.children { if let b = node as? BlockBall { b.stopSpeedThreshold = newValue } }
        saveSetting(SettingsKey.stopSpeedThreshold, value: Double(newValue))
        handle.position.x = trackX + (-trackWidth/2 + t * trackWidth)
        if let valueLabel = contentNode.childNode(withName: "//stopSpeedValue") as? SKLabelNode { valueLabel.text = formatSpeed(newValue) }
    }
    
    private func updateStopAngularSlider(touchLocation: CGPoint, track: SKShapeNode, handle: SKShapeNode) {
        guard let scene = scene as? StarfieldScene else { return }
        guard let contentNode = overlayContentNode else { return }
        let trackWidth = track.frame.width
        let trackX = track.position.x
        let relativeX = touchLocation.x - trackX
        let clampedX = max(-trackWidth/2, min(trackWidth/2, relativeX))
        let t = (clampedX + trackWidth/2) / trackWidth
        let minVal: CGFloat = 0.0
        let maxVal: CGFloat = 5.0
        let newValue = minVal + t * (maxVal - minVal)
        for node in scene.children { if let b = node as? BlockBall { b.stopAngularThreshold = newValue } }
        saveSetting(SettingsKey.stopAngularThreshold, value: Double(newValue))
        handle.position.x = trackX + (-trackWidth/2 + t * trackWidth)
        if let valueLabel = contentNode.childNode(withName: "//stopAngValue") as? SKLabelNode { valueLabel.text = formatDamping(newValue) }
    }
    
    // MARK: - Added Sliders - update4BallMaxTriggersSliderUI correction
    
    private func update4BallMaxTriggersSliderUI(trackNode: SKShapeNode, handleNode: SKShapeNode, valueLabel: SKLabelNode, value: Int) {
        // Snap to 1...5
        let clamped = max(1, min(5, value))
        valueLabel.text = "\(clamped)x"
        
        // Position handle along track based on value
        let trackWidth = trackNode.frame.width
        let trackX = trackNode.position.x
        let t = CGFloat(clamped - 1) / CGFloat(5 - 1) // 0...1
        let xOffset = -trackWidth/2 + t * trackWidth
        handleNode.position.x = trackX + xOffset
        handleNode.position.y = trackNode.position.y
        
        // Apply to config and persist
        if let scene = scene as? StarfieldScene {
            scene.damageSystem?.config.fourBallMaxTriggers = clamped
            saveSetting(SettingsKey.fourBallMaxTriggers, value: clamped)
        }
    }
    
    private func update4BallMaxTriggersSlider(at location: CGPoint) {
        guard let contentNode = overlayContentNode else { return }
        guard let track = contentNode.childNode(withName: "//fourBallMaxTriggersTrack") as? SKShapeNode,
              let handle = contentNode.childNode(withName: "//fourBallMaxTriggersHandle") as? SKShapeNode,
              let valueLabel = contentNode.childNode(withName: "//fourBallMaxTriggersValue") as? SKLabelNode else { return }
        
        let trackWidth = track.frame.width
        
        let clampedX = max(-trackWidth/2, min(trackWidth/2, location.x))
        let t = (clampedX + trackWidth/2) / trackWidth
        let raw = 1.0 + t * 4.0
        let snapped = Int(round(raw))
        
        update4BallMaxTriggersSliderUI(trackNode: track, handleNode: handle, valueLabel: valueLabel, value: snapped)
    }
    
    // MARK: - Formatting helpers
    
    private func formatMaxShotDistance(_ value: CGFloat) -> String {
        return "\(Int(value))"
    }
    
    private func formatPowerExponent(_ value: CGFloat) -> String {
        return String(format: "%.1f", value)
    }
    
    private func format4BallRadius(_ value: CGFloat) -> String {
        return String(format: "%.1f blks", value)
    }
    
    private func formatFriction(_ value: CGFloat) -> String {
        return String(format: "%.2f", value)
    }
    
    private func formatDamping(_ value: CGFloat) -> String {
        return String(format: "%.2f", value)
    }
    
    private func formatRestitution(_ value: CGFloat) -> String {
        return String(format: "%.2f", value)
    }
    
    private func formatSpeed(_ value: CGFloat) -> String {
        return "\(Int(value))"
    }
    
    private func formatDuration(_ value: CGFloat) -> String {
        return String(format: "%.2f", value)
    }
    
    // MARK: - Existing slider code below (unchanged) ...
    
    private func add3BallMassSliderToNode(_ parent: SKNode, width: CGFloat, yCursor: CGFloat) -> CGFloat {
        guard let scene = scene as? StarfieldScene else { return yCursor }
        
        var y = yCursor
        
        // Label
        let label = SKLabelNode(fontNamed: "Courier")
        label.text = "3-Ball Mass Multiplier"
        label.fontSize = 14
        label.fontColor = .white
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: -width/2 + 16, y: y)
        label.zPosition = 1
        parent.addChild(label)
        
        // Get current mass multiplier from a 3ball
        var currentMultiplier: CGFloat = 30  // Default
        for node in scene.children {
            if let ball = node as? BlockBall, ball.ballKind == .three, let body = ball.physicsBody {
                // Calculate multiplier from actual mass (0.17 is base mass)
                currentMultiplier = body.mass / 0.17
                break
            }
        }
        
        // Value label
        let valueLabel = SKLabelNode(fontNamed: "Courier-Bold")
        valueLabel.text = format3BallMass(currentMultiplier)
        valueLabel.fontSize = 14
        valueLabel.fontColor = .white
        valueLabel.horizontalAlignmentMode = .right
        valueLabel.verticalAlignmentMode = .center
        valueLabel.position = CGPoint(x: width/2 - 16, y: y)
        valueLabel.zPosition = 1
        valueLabel.name = "threeBallMassValue"
        parent.addChild(valueLabel)
        
        y -= 15
        
        // Track
        let trackWidth: CGFloat = width - 32
        let trackHeight: CGFloat = 4
        let track = SKShapeNode(rectOf: CGSize(width: trackWidth, height: trackHeight), cornerRadius: 2)
        track.fillColor = SKColor(white: 1.0, alpha: 0.3)
        track.strokeColor = .clear
        track.zPosition = 1
        track.name = "threeBallMassTrack"
        track.position = CGPoint(x: 0, y: y)
        parent.addChild(track)
        
        // Handle
        let handleSize = CGSize(width: 20, height: 20)
        let handle = SKShapeNode(rectOf: handleSize, cornerRadius: 4)
        handle.fillColor = SKColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0)  // Red handle for 3ball
        handle.strokeColor = .clear
        handle.zPosition = 2
        handle.name = "threeBallMassHandle"
        
        // Position handle based on current multiplier (0-50 range)
        let minVal: CGFloat = 0
        let maxVal: CGFloat = 50
        let t = (currentMultiplier - minVal) / (maxVal - minVal)
        let xOffset = -trackWidth/2 + t * trackWidth
        handle.position = CGPoint(x: xOffset, y: y)
        parent.addChild(handle)
        
        return y - 15
    }
    
    private func update3BallMassSlider(touchLocation: CGPoint, track: SKShapeNode, handle: SKShapeNode) {
        guard let scene = scene as? StarfieldScene else { return }
        guard let contentNode = overlayContentNode else { return }
        
        let trackWidth = track.frame.width
        let trackX = track.position.x
        
        // Calculate relative X position on track
        let relativeX = touchLocation.x - trackX
        let clampedX = max(-trackWidth/2, min(trackWidth/2, relativeX))
        let t = (clampedX + trackWidth/2) / trackWidth
        
        // Map to 0-50 range
        let minVal: CGFloat = 0
        let maxVal: CGFloat = 50
        let multiplier = minVal + t * (maxVal - minVal)
        
        // Update all 3balls' mass
        scene.update3BallMass(multiplier: multiplier)
        
        // Save to UserDefaults
        saveSetting(SettingsKey.threeBallMass, value: Double(multiplier))
        
        // Move handle
        let xOffset = -trackWidth/2 + t * trackWidth
        handle.position.x = trackX + xOffset
        
        // Update value label
        if let valueLabel = contentNode.childNode(withName: "//threeBallMassValue") as? SKLabelNode {
            valueLabel.text = format3BallMass(multiplier)
        }
        
        print("🎚️ 3-Ball Mass Multiplier set to \(String(format: "%.1f", multiplier))× (mass: \(String(format: "%.2f", multiplier * 0.17)))")
    }
    
    private func format3BallMass(_ multiplier: CGFloat) -> String {
        return String(format: "%.1f×", multiplier)
    }
    
    private func addMaxImpulseSliderToNode(_ parent: SKNode, width: CGFloat, yCursor: CGFloat) -> CGFloat {
        guard let scene = scene as? StarfieldScene else { return yCursor }
        
        var y = yCursor
        
        // Label
        let label = SKLabelNode(fontNamed: "Courier")
        label.text = "Max Shot Power"
        label.fontSize = 14
        label.fontColor = .white
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: -width/2 + 16, y: y)
        label.zPosition = 1
        parent.addChild(label)
        
        // Get current max impulse from an actual ball
        var currentValue: CGFloat = 300
        for node in scene.children {
            if let ball = node as? BlockBall {
                currentValue = ball.maxImpulse
                break
            }
        }
        
        // Value label
        let valueLabel = SKLabelNode(fontNamed: "Courier-Bold")
        valueLabel.text = formatMaxImpulse(currentValue)
        valueLabel.fontSize = 14
        valueLabel.fontColor = .white
        valueLabel.horizontalAlignmentMode = .right
        valueLabel.verticalAlignmentMode = .center
        valueLabel.position = CGPoint(x: width/2 - 16, y: y)
        valueLabel.zPosition = 1
        valueLabel.name = "maxImpulseValue"
        parent.addChild(valueLabel)
        
        y -= 15
        
        // Track
        let trackWidth: CGFloat = width - 32
        let trackHeight: CGFloat = 4
        let track = SKShapeNode(rectOf: CGSize(width: trackWidth, height: trackHeight), cornerRadius: 2)
        track.fillColor = SKColor(white: 1.0, alpha: 0.3)
        track.strokeColor = .clear
        track.zPosition = 1
        track.name = "maxImpulseTrack"
        track.position = CGPoint(x: 0, y: y)
        parent.addChild(track)
        
        // Handle
        let handleSize = CGSize(width: 20, height: 20)
        let handle = SKShapeNode(rectOf: handleSize, cornerRadius: 4)
        handle.fillColor = .white
        handle.strokeColor = .clear
        handle.zPosition = 2
        handle.name = "maxImpulseHandle"
        
        // Position handle based on current value (0-300 range)
        let minVal: CGFloat = 0
        let maxVal: CGFloat = 300
        let t = (currentValue - minVal) / (maxVal - minVal)
        let xOffset = -trackWidth/2 + t * trackWidth
        handle.position = CGPoint(x: xOffset, y: y)
        parent.addChild(handle)
        
        return y - 15
    }
    
    private func updateMaxImpulseSlider(touchLocation: CGPoint, track: SKShapeNode, handle: SKShapeNode) {
        guard let scene = scene as? StarfieldScene else { return }
        guard let contentNode = overlayContentNode else { return }
        
        let trackWidth = track.frame.width
        let trackX = track.position.x
        
        // Calculate relative X position on track
        let relativeX = touchLocation.x - trackX
        let clampedX = max(-trackWidth/2, min(trackWidth/2, relativeX))
        let t = (clampedX + trackWidth/2) / trackWidth
        
        // Map to 0-300 range
        let minVal: CGFloat = 0
        let maxVal: CGFloat = 300
        let newValue = minVal + t * (maxVal - minVal)
        
        // Update all cue balls' max impulse
        // Note: Since maxImpulse is private, we need to make it accessible
        // For now, this will be stored and we'll need to modify BlockBall
        scene.updateMaxImpulseForAllBalls(newValue)
        
        // Save to UserDefaults
        saveSetting(SettingsKey.maxImpulse, value: Double(newValue))
        
        // Move handle
        let xOffset = -trackWidth/2 + t * trackWidth
        handle.position.x = trackX + xOffset
        
        // Update value label
        if let valueLabel = contentNode.childNode(withName: "//maxImpulseValue") as? SKLabelNode {
            valueLabel.text = formatMaxImpulse(newValue)
        }
        
        print("🎚️ Max Shot Power set to \(Int(newValue))")
    }
    
    private func formatMaxImpulse(_ value: CGFloat) -> String {
        return "\(Int(value))"
    }
    
    private func addDamageMultiplierSliderToNode(_ parent: SKNode, width: CGFloat, yCursor: CGFloat) -> CGFloat {
        guard let scene = scene as? StarfieldScene else { return yCursor }
        
        var y = yCursor
        
        // Label
        let label = SKLabelNode(fontNamed: "Courier")
        label.text = "Damage Multiplier"
        label.fontSize = 14
        label.fontColor = .white
        label.horizontalAlignmentMode = .left
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: -width/2 + 16, y: y)
        label.zPosition = 1
        parent.addChild(label)
        
        // Value label
        let currentValue = scene.damageSystem?.config.damageMultiplier ?? 1.0
        let valueLabel = SKLabelNode(fontNamed: "Courier-Bold")
        valueLabel.text = formatDamageMultiplier(currentValue)
        valueLabel.fontSize = 14
        valueLabel.fontColor = .white
        valueLabel.horizontalAlignmentMode = .right
        valueLabel.verticalAlignmentMode = .center
        valueLabel.position = CGPoint(x: width/2 - 16, y: y)
        valueLabel.zPosition = 1
        valueLabel.name = "damageMultiplierValue"
        parent.addChild(valueLabel)
        
        y -= 15
        
        // Track
        let trackWidth: CGFloat = width - 32
        let trackHeight: CGFloat = 4
        let track = SKShapeNode(rectOf: CGSize(width: trackWidth, height: trackHeight), cornerRadius: 2)
        track.fillColor = SKColor(white: 1.0, alpha: 0.3)
        track.strokeColor = .clear
        track.zPosition = 1
        track.name = "damageMultiplierTrack"
        track.position = CGPoint(x: 0, y: y)
        parent.addChild(track)
        
        // Handle
        let handleSize = CGSize(width: 20, height: 20)
        let handle = SKShapeNode(rectOf: handleSize, cornerRadius: 4)
        handle.fillColor = .white
        handle.strokeColor = .clear
        handle.zPosition = 2
        handle.name = "damageMultiplierHandle"
        
        // Position handle based on current value (1.0-10.0 range)
        let minVal: CGFloat = 1.0
        let maxVal: CGFloat = 10.0
        let t = (currentValue - minVal) / (maxVal - minVal)
        let xOffset = -trackWidth/2 + t * trackWidth
        handle.position = CGPoint(x: xOffset, y: y)
        parent.addChild(handle)
        
        return y - 15
    }
    
    private func formatDamageMultiplier(_ value: CGFloat) -> String {
        if value == 1.0 {
            return "1× (Normal)"
        } else if value == 10.0 {
            return "10× (Instant Kill)"
        } else {
            return String(format: "%.1f×", value)
        }
    }
    
    private func createToggleButton(title: String, position: CGPoint, name: String, enabled: Bool) -> SKShapeNode {
        let buttonWidth: CGFloat = 250
        let buttonHeight: CGFloat = 44
        let button = SKShapeNode(rectOf: CGSize(width: buttonWidth, height: buttonHeight), cornerRadius: 10)
        button.name = name
        button.fillColor = enabled ? SKColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0) : SKColor(white: 0.3, alpha: 1.0)
        button.strokeColor = SKColor(white: 1.0, alpha: 0.3)
        button.lineWidth = 2
        button.position = position
        
        let label = SKLabelNode(fontNamed: "Courier-Bold")
        label.text = enabled ? "✓ \(title)" : title
        label.fontSize = 14
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        label.position = .zero
        label.zPosition = 2
        label.name = "label"
        button.addChild(label)
        
        return button
    }
    
    private func updateToggleButton(_ button: SKShapeNode, enabled: Bool, title: String) {
        button.fillColor = enabled ? SKColor(red: 0.2, green: 0.7, blue: 0.3, alpha: 1.0) : SKColor(white: 0.3, alpha: 1.0)
        if let label = button.childNode(withName: "label") as? SKLabelNode {
            label.text = enabled ? "✓ \(title)" : title
        }
    }
    
    private func sliderValue(for spec: SliderSpec, from locationInBG: CGPoint, trackWidth: CGFloat) -> CGFloat {
        let clampedX = max(-trackWidth/2, min(trackWidth/2, locationInBG.x))
        let t = (clampedX + trackWidth/2) / trackWidth
        return spec.min + t * (spec.max - spec.min)
    }
    
    // MARK: - Flying Accessory Testing
    
    /// Test the flying accessory by attaching it to all cue balls
    private func testFlyingAccessory() {
        guard let scene = scene as? StarfieldScene else { return }
        
        var cueBallsFound = 0
        var alreadyHadAccessory = 0
        var newlyAttached = 0
        
        // Find all cue balls and toggle flying accessory
        for node in scene.children {
            guard let ball = node as? BlockBall, ball.ballKind == .cue else { continue }
            cueBallsFound += 1
            
            if ball.hasAccessory("flying") {
                // Remove if already has it
                if ball.removeAccessory("flying") {
                    alreadyHadAccessory += 1
                    print("🪽 Removed flying accessory from cue ball")
                }
            } else {
                // Attach if doesn't have it
                if ball.attachAccessory("flying") {
                    newlyAttached += 1
                    print("🪽 Attached flying accessory to cue ball")
                }
            }
        }
        
        // Print summary
        if cueBallsFound == 0 {
            print("⚠️ No cue balls found to test flying accessory")
        } else if newlyAttached > 0 {
            print("✅ Flying accessory attached to \(newlyAttached) cue ball(s)")
        } else if alreadyHadAccessory > 0 {
            print("✅ Flying accessory removed from \(alreadyHadAccessory) cue ball(s)")
        }
    }
}

private extension SKNode {
    func addChildren(_ nodes: [SKNode]) { for n in nodes { addChild(n) } }
}

