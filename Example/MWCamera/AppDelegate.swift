//
//  AppDelegate.swift
//  MWCamera
//
//  Created by woodyjl on 05/14/2019.
//  Copyright (c) 2019 woodyjl. All rights reserved.
//

import UIKit
import AVFoundation
import MWCamera
// swiftlint:disable line_length
@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        self.setAppAudioSettings()
        self.window = UIWindow(frame: UIScreen.main.bounds)
        let mainController = ViewController()
        self.window?.rootViewController = mainController
        self.window?.makeKeyAndVisible()
        return true
    }

    public func setAppAudioSettings() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            let options: AVAudioSession.CategoryOptions = [
                .mixWithOthers
            ]
            try audioSession.setActive(false)
            try audioSession.setCategory(AVAudioSession.Category.playback, options: options)
            try audioSession.setActive(true)
        } catch {
            print(error)
            print("Failed to set background audio preference \(error.localizedDescription)")
        }
    }
}
