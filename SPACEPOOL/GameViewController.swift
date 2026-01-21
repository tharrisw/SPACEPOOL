//
//  GameViewController.swift
//  SpacePool
//
//  Created by Thomas Harris-Warrick on 1/16/26.
//

import UIKit
import SpriteKit

class GameViewController: UIViewController {
    override func loadView() {
        let skView = SKView(frame: UIScreen.main.bounds)
        skView.backgroundColor = .black
        skView.isOpaque = true
        view = skView
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard let skView = view as? SKView else { return }
        
        let scene = StarfieldScene(size: skView.bounds.size)
        scene.backgroundColor = .black
        scene.scaleMode = .resizeFill
        
        skView.presentScene(scene)
        skView.ignoresSiblingOrder = true
        
        // Performance stats
        skView.showsFPS = true
        skView.showsNodeCount = true
        skView.showsDrawCount = true
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }

    override var prefersStatusBarHidden: Bool { true }
}

