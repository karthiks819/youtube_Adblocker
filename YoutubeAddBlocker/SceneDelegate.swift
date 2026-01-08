//
//  SceneDelegate.swift
//  YoutubeAddBlocker
//
//  Created by Karthik Solleti on 08/01/26.
//

import UIKit
import AVFoundation

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?


    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        // Set up TabBarController as root if not set by storyboard
        if window == nil {
            window = UIWindow(windowScene: windowScene)
            let tabBarController = TabBarController()
            window?.rootViewController = tabBarController
            window?.makeKeyAndVisible()
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }


    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
        // Keep audio session active for background playback
        activateAudioSession()
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
        activateAudioSession()
        
        // Refresh Now Playing info when app comes to foreground
        refreshNowPlayingInfo()
    }
    
    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
        activateAudioSession()
        
        // Refresh Now Playing info when app becomes active
        refreshNowPlayingInfo()
    }
    
    private func refreshNowPlayingInfo() {
        // Find ViewController and refresh Now Playing info
        guard let windowScene = window?.windowScene,
              let window = windowScene.windows.first else { return }
        
        // Try to find MusicViewController in the view hierarchy
        func findMusicViewController(in viewController: UIViewController?) -> MusicViewController? {
            if let vc = viewController as? MusicViewController {
                return vc
            }
            for child in viewController?.children ?? [] {
                if let found = findMusicViewController(in: child) {
                    return found
                }
            }
            if let nav = viewController as? UINavigationController {
                return findMusicViewController(in: nav.topViewController)
            }
            if let tab = viewController as? UITabBarController {
                return findMusicViewController(in: tab.selectedViewController)
            }
            return nil
        }
        
        if let musicViewController = findMusicViewController(in: window.rootViewController) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                musicViewController.refreshNowPlayingInfoIfNeeded()
            }
        }
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
        // Ensure audio session stays active for background playback and PIP
        activateAudioSession()
        
        // Keep video playing in PIP when app goes to background
        if let windowScene = window?.windowScene,
           let window = windowScene.windows.first {
            findVideoViewController(in: window.rootViewController)?.maintainPIPPlayback()
        }
    }
    
    private func findVideoViewController(in viewController: UIViewController?) -> VideoViewController? {
        if let vc = viewController as? VideoViewController {
            return vc
        }
        for child in viewController?.children ?? [] {
            if let found = findVideoViewController(in: child) {
                return found
            }
        }
        if let nav = viewController as? UINavigationController {
            return findVideoViewController(in: nav.topViewController)
        }
        if let tab = viewController as? UITabBarController {
            return findVideoViewController(in: tab.selectedViewController)
        }
        return nil
    }
    
    private func activateAudioSession() {
        // Only activate audio session if needed and not already configured
        let audioSession = AVAudioSession.sharedInstance()
        let currentCategory = audioSession.category
        let currentMode = audioSession.mode
        
        // Check if already configured correctly
        if currentCategory == .playback {
            // Already configured, just ensure it's active if needed
            if !audioSession.isOtherAudioPlaying {
                do {
                    try audioSession.setActive(true, options: [])
                } catch {
                    // Silently fail if already active or in use
                }
            }
            return
        }
        
        do {
            // Only set category if different
            if currentCategory != .playback || currentMode != .default {
                try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers, .allowAirPlay])
            }
            
            // Only activate if not already active and no other audio is playing
            if !audioSession.isOtherAudioPlaying {
                try audioSession.setActive(true, options: [])
            }
        } catch {
            // Silently fail - audio session might already be configured
            print("Failed to activate audio session in SceneDelegate: \(error.localizedDescription)")
        }
    }


}

