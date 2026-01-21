//
//  AppDelegate.swift
//  SpacePool
//
//  Created by Thomas Harris-Warrick on 1/16/26.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.backgroundColor = .black
        window?.rootViewController = GameViewController()
        window?.makeKeyAndVisible()
        return true
    }
}

