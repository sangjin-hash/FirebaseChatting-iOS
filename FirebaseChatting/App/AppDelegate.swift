//
//  AppDelegate.swift
//  FirebaseChatting
//
//  Created by Sangjin Lee
//

import UIKit
import FirebaseCore
import GoogleSignIn
import FirebaseAuth

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        guard !ProcessInfo.processInfo.arguments.contains("-UITesting") else {
            return true
        }
        FirebaseApp.configure()
        return true
    }
    
    func application(_ app: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
    }
}
