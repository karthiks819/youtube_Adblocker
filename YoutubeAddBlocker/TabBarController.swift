//
//  TabBarController.swift
//  YoutubeAddBlocker
//
//  Created by Karthik Solleti on 08/01/26.
//

import UIKit

class TabBarController: UITabBarController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabs()
    }
    
    private func setupTabs() {
        // Create Video tab
        let videoViewController = VideoViewController()
        videoViewController.tabBarItem = UITabBarItem(title: "Video", image: UIImage(systemName: "play.rectangle"), selectedImage: UIImage(systemName: "play.rectangle.fill"))
        let videoNavController = UINavigationController(rootViewController: videoViewController)
        
        // Create Music tab
        let musicViewController = MusicViewController()
        musicViewController.tabBarItem = UITabBarItem(title: "Music", image: UIImage(systemName: "music.note"), selectedImage: UIImage(systemName: "music.note"))
        let musicNavController = UINavigationController(rootViewController: musicViewController)
        
        // Set view controllers
        viewControllers = [videoNavController, musicNavController]
        
        // Set default selected tab (Video)
        selectedIndex = 0
        
        // Customize tab bar appearance
        tabBar.tintColor = .systemRed
        tabBar.unselectedItemTintColor = .systemGray
        tabBar.backgroundColor = .systemBackground
        tabBar.barTintColor = .systemBackground
        
        // Set navigation bar appearance to match
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .systemBackground
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
}
