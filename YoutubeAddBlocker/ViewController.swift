//
//  MusicViewController.swift
//  YoutubeAddBlocker
//
//  Created by Karthik Solleti on 08/01/26.
//

import UIKit
import WebKit
import AVFoundation
import MediaPlayer

class MusicViewController: UIViewController {
    
    private var webView: WKWebView!
    private var contentRuleList: WKContentRuleList?
    private let commandCenter = MPRemoteCommandCenter.shared()
    private var nowPlayingUpdateTimer: Timer?
    private var silentModeCheckTimer: Timer?
    private var wasPlayingBeforeSilentMode = false
    private var isPausedDueToSilentMode = false

    
    private func setupRemoteCommandCenter() {
        // Enable lock screen controls
        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.isEnabled = true
        
        // Handle play command from lock screen
        commandCenter.playCommand.addTarget { [weak self] event -> MPRemoteCommandHandlerStatus in
            guard let self = self else { return .commandFailed }
            
            print("🔵 Play command received from lock screen")
            
            DispatchQueue.main.async {
                self.executeJavaScript("""
                    (function() {
                        console.log('Play command executing...');
                        
                        // Method 1: Try to find and play media element directly
                        const media = document.querySelector('video, audio');
                        if (media) {
                            console.log('Found media element, playing...');
                            // Clear user pause flag when user plays
                            userManuallyPaused = false;
                            pauseTime = 0;
                            media.play().catch(e => console.log('Play error:', e));
                            return true;
                        }
                        
                        // Method 2: Try YouTube Music player bar play button
                        const playerBar = document.querySelector('ytmusic-player-bar, .ytmusic-player-bar');
                        if (playerBar) {
                            const playBtn = playerBar.querySelector('button[aria-label*="Play"], button[aria-label*="play"], button[title*="Play"], button[title*="play"]');
                            if (playBtn) {
                                console.log('Found play button in player bar, clicking...');
                                playBtn.click();
                                return true;
                            }
                        }
                        
                        // Method 3: Try all play buttons with various selectors
                        const playSelectors = [
                            '[aria-label*="Play"]',
                            '[aria-label*="play"]',
                            '[title*="Play"]',
                            '[title*="play"]',
                            '.ytp-play-button',
                            'button[aria-label*="Play"]',
                            'button[title*="Play"]'
                        ];
                        
                        for (let selector of playSelectors) {
                            const btn = document.querySelector(selector);
                            if (btn && btn.offsetParent !== null) { // Check if visible
                                console.log('Found play button with selector:', selector);
                                btn.click();
                                return true;
                            }
                        }
                        
                        // Method 4: Try to find any button with play in aria-label or title
                        const allButtons = document.querySelectorAll('button');
                        for (let btn of allButtons) {
                            const ariaLabel = (btn.getAttribute('aria-label') || '').toLowerCase();
                            const title = (btn.getAttribute('title') || '').toLowerCase();
                            if ((ariaLabel.includes('play') || title.includes('play')) && btn.offsetParent !== null) {
                                console.log('Found play button by text search');
                                btn.click();
                                return true;
                            }
                        }
                        
                        console.log('No play button found');
                        return false;
                    })();
                """) { result, error in
                    if let error = error {
                        print("❌ Play command error: \(error)")
                    } else {
                        print("✅ Play command executed, result: \(result ?? "nil")")
                        // Update Now Playing info after play
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.updateNowPlayingPlaybackState()
                        }
                    }
                }
            }
            return .success
        }
        
        // Handle pause command from lock screen
        commandCenter.pauseCommand.addTarget { [weak self] event -> MPRemoteCommandHandlerStatus in
            guard let self = self else { return .commandFailed }
            
            print("🔴 Pause command received from lock screen")
            
            DispatchQueue.main.async {
                self.executeJavaScript("""
                    (function() {
                        console.log('Pause command executing...');
                        
                        // CRITICAL: Set user pause flag FIRST to prevent auto-resume
                        if (typeof userManuallyPaused !== 'undefined') {
                            userManuallyPaused = true;
                            pauseTime = Date.now();
                            console.log('User pause flag set - will not auto-resume');
                        }
                        
                        // Method 1: Try to find and pause media element directly
                        const media = document.querySelector('video, audio');
                        if (media) {
                            console.log('Found media element, pausing...');
                            media.pause();
                            // Ensure flag is set
                            if (typeof userManuallyPaused !== 'undefined') {
                                userManuallyPaused = true;
                                pauseTime = Date.now();
                            }
                            return true;
                        }
                        
                        // Method 2: Try YouTube Music player bar pause button
                        const playerBar = document.querySelector('ytmusic-player-bar, .ytmusic-player-bar');
                        if (playerBar) {
                            const pauseBtn = playerBar.querySelector('button[aria-label*="Pause"], button[aria-label*="pause"], button[title*="Pause"], button[title*="pause"]');
                            if (pauseBtn) {
                                console.log('Found pause button in player bar, clicking...');
                                pauseBtn.click();
                                return true;
                            }
                        }
                        
                        // Method 3: Try all pause buttons with various selectors
                        const pauseSelectors = [
                            '[aria-label*="Pause"]',
                            '[aria-label*="pause"]',
                            '[title*="Pause"]',
                            '[title*="pause"]',
                            '.ytp-pause-button',
                            'button[aria-label*="Pause"]',
                            'button[title*="Pause"]'
                        ];
                        
                        for (let selector of pauseSelectors) {
                            const btn = document.querySelector(selector);
                            if (btn && btn.offsetParent !== null) { // Check if visible
                                console.log('Found pause button with selector:', selector);
                                btn.click();
                                return true;
                            }
                        }
                        
                        // Method 4: Try to find any button with pause in aria-label or title
                        const allButtons = document.querySelectorAll('button');
                        for (let btn of allButtons) {
                            const ariaLabel = (btn.getAttribute('aria-label') || '').toLowerCase();
                            const title = (btn.getAttribute('title') || '').toLowerCase();
                            if ((ariaLabel.includes('pause') || title.includes('pause')) && btn.offsetParent !== null) {
                                console.log('Found pause button by text search');
                                btn.click();
                                return true;
                            }
                        }
                        
                        console.log('No pause button found');
                        return false;
                    })();
                """) { result, error in
                    if let error = error {
                        print("❌ Pause command error: \(error)")
                    } else {
                        print("✅ Pause command executed, result: \(result ?? "nil")")
                        // Update Now Playing info after pause
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.updateNowPlayingPlaybackState()
                        }
                    }
                }
            }
            return .success
        }
        
        // Handle toggle play/pause from lock screen
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] event -> MPRemoteCommandHandlerStatus in
            guard let self = self else { return .commandFailed }
            
            print("🔄 Toggle play/pause command received from lock screen")
            
            DispatchQueue.main.async {
                self.executeJavaScript("""
                    (function() {
                        console.log('Toggle play/pause command executing...');
                        
                        // Method 1: Try media element first (most reliable)
                        const media = document.querySelector('video, audio');
                        if (media) {
                            console.log('Found media element, toggling...');
                            if (media.paused) {
                                // Clear user pause flag when user plays
                                userManuallyPaused = false;
                                pauseTime = 0;
                                media.play().catch(e => console.log('Play error:', e));
                            } else {
                                // Mark as user-initiated pause
                                userManuallyPaused = true;
                                pauseTime = Date.now();
                                media.pause();
                            }
                            return true;
                        }
                        
                        // Method 2: Try YouTube Music player bar toggle button
                        const playerBar = document.querySelector('ytmusic-player-bar, .ytmusic-player-bar');
                        if (playerBar) {
                            const toggleBtn = playerBar.querySelector('button[aria-label*="Play"], button[aria-label*="Pause"], button[aria-label*="play"], button[aria-label*="pause"]');
                            if (toggleBtn) {
                                console.log('Found toggle button in player bar, clicking...');
                                toggleBtn.click();
                                return true;
                            }
                        }
                        
                        // Method 3: Try play/pause buttons
                        const toggleSelectors = [
                            '[aria-label*="Play"]',
                            '[aria-label*="Pause"]',
                            '[aria-label*="play"]',
                            '[aria-label*="pause"]',
                            '.ytp-play-button',
                            '.ytp-pause-button'
                        ];
                        
                        for (let selector of toggleSelectors) {
                            const btn = document.querySelector(selector);
                            if (btn && btn.offsetParent !== null) {
                                console.log('Found toggle button with selector:', selector);
                                btn.click();
                                return true;
                            }
                        }
                        
                        console.log('No toggle button found');
                        return false;
                    })();
                """) { result, error in
                    if let error = error {
                        print("❌ Toggle play/pause error: \(error)")
                    } else {
                        print("✅ Toggle play/pause executed, result: \(result ?? "nil")")
                        // Update Now Playing info after toggle
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.updateNowPlayingPlaybackState()
                        }
                    }
                }
            }
            return .success
        }
        
        // Handle next track
        commandCenter.nextTrackCommand.addTarget { [weak self] event -> MPRemoteCommandHandlerStatus in
            guard let self = self else { return .commandFailed }
            
            print("⏭️ Next track command received")
            
            DispatchQueue.main.async {
                self.executeJavaScript("""
                    (function() {
                        const nextButton = document.querySelector('[aria-label*="Next"], [aria-label*="next"], [title*="Next"], [title*="next"], .ytp-next-button, button[aria-label*="Skip"]');
                        if (nextButton) {
                            nextButton.click();
                            return true;
                        }
                        return false;
                    })();
                """) { [weak self] result, error in
                    if let error = error {
                        print("❌ Next track error: \(error)")
                    } else {
                        print("✅ Next track clicked, waiting for new song to load...")
                        // Wait for new song to start, then update Now Playing info
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self?.updateNowPlayingInfoForNewTrack()
                        }
                    }
                }
            }
            return .success
        }
        
        // Handle previous track
        commandCenter.previousTrackCommand.addTarget { [weak self] event -> MPRemoteCommandHandlerStatus in
            guard let self = self else { return .commandFailed }
            
            print("⏮️ Previous track command received")
            
            DispatchQueue.main.async {
                self.executeJavaScript("""
                    (function() {
                        const prevButton = document.querySelector('[aria-label*="Previous"], [aria-label*="previous"], [title*="Previous"], [title*="previous"], .ytp-prev-button');
                        if (prevButton) {
                            prevButton.click();
                            return true;
                        }
                        return false;
                    })();
                """) { [weak self] result, error in
                    if let error = error {
                        print("❌ Previous track error: \(error)")
                    } else {
                        print("✅ Previous track clicked, waiting for new song to load...")
                        // Wait for new song to start, then update Now Playing info
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self?.updateNowPlayingInfoForNewTrack()
                        }
                    }
                }
            }
            return .success
        }
    }
    
    private func executeJavaScript(_ script: String, retryCount: Int = 0) {
        // Ensure web view is ready before executing
        guard let webView = webView else {
            if retryCount < 3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.executeJavaScript(script, retryCount: retryCount + 1)
                }
            }
            return
        }
        
        // Check if web view is loaded
        guard webView.url != nil || retryCount > 0 else {
            // Web view not loaded yet, retry
            if retryCount < 3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    self?.executeJavaScript(script, retryCount: retryCount + 1)
                }
            }
            return
        }
        
        webView.evaluateJavaScript(script) { result, error in
            if let error = error {
                print("JavaScript execution error: \(error)")
                // Retry if web view might not be ready
                if retryCount < 2 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                        self?.executeJavaScript(script, retryCount: retryCount + 1)
                    }
                }
            }
        }
    }
    
    private func executeJavaScript(_ script: String, completion: @escaping (Any?, Error?) -> Void) {
        webView.evaluateJavaScript(script, completionHandler: completion)
    }
    
    private func updateNowPlayingInfo(title: String, artist: String, artworkURL: String?, duration: Double? = nil, currentTime: Double? = nil, isPlaying: Bool? = nil) {
        // Ensure audio session is active
        activateAudioSession()
        
        // If duration and currentTime are provided, use them directly (for new tracks)
        if let duration = duration, let currentTime = currentTime, let isPlaying = isPlaying {
            DispatchQueue.main.async {
                var nowPlayingInfo = [String: Any]()
                nowPlayingInfo[MPMediaItemPropertyTitle] = title
                nowPlayingInfo[MPMediaItemPropertyArtist] = artist
                nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration > 0 ? duration : 180.0
                nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
                nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
                
                // Set Now Playing info immediately
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
                print("🎵 Now Playing Info set (with provided values) - Title: \(title), Duration: \(duration), CurrentTime: \(currentTime), Rate: \(isPlaying ? 1.0 : 0.0)")
                
                // Load artwork asynchronously if URL is provided
                if let artworkURLString = artworkURL, !artworkURLString.isEmpty,
                   let url = URL(string: artworkURLString) {
                    var request = URLRequest(url: url)
                    request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
                    
                    URLSession.shared.dataTask(with: request) { data, response, error in
                        if let error = error {
                            print("Error loading artwork: \(error.localizedDescription)")
                            return
                        }
                        
                        guard let data = data, let image = UIImage(data: data) else {
                            print("Failed to create image from artwork data")
                            return
                        }
                        
                        let artwork = MPMediaItemArtwork(boundsSize: CGSize(width: 500, height: 500)) { _ in image }
                        
                        DispatchQueue.main.async {
                            var updatedInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String: Any]()
                            updatedInfo[MPMediaItemPropertyArtwork] = artwork
                            MPNowPlayingInfoCenter.default().nowPlayingInfo = updatedInfo
                        }
                    }.resume()
                }
                return
            }
        }
        
        // If parameters not provided, query JavaScript for playback state
        executeJavaScript("""
            (function() {
                const media = document.querySelector('video, audio');
                if (media) {
                    return {
                        duration: media.duration || 0,
                        currentTime: media.currentTime || 0,
                        isPlaying: !media.paused
                    };
                }
                return { duration: 0, currentTime: 0, isPlaying: false };
            })();
        """) { [weak self] (result: Any?, error: Error?) in
            DispatchQueue.main.async {
                var nowPlayingInfo = [String: Any]()
                nowPlayingInfo[MPMediaItemPropertyTitle] = title
                nowPlayingInfo[MPMediaItemPropertyArtist] = artist
                
                if let playbackState = result as? [String: Any] {
                    let duration = playbackState["duration"] as? Double ?? 0
                    let currentTime = playbackState["currentTime"] as? Double ?? 0
                    let isPlaying = playbackState["isPlaying"] as? Bool ?? false
                    
                    nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration > 0 ? duration : 180.0
                    nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
                    nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
                } else {
                    nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = 180.0
                    nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = 0
                    nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
                }
                
                // Set Now Playing info
                MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
                print("🎵 Now Playing Info set (from JS query) - Title: \(title), Artist: \(artist)")
                
                // Load artwork asynchronously if URL is provided
                if let artworkURLString = artworkURL, !artworkURLString.isEmpty,
                   let url = URL(string: artworkURLString) {
                    var request = URLRequest(url: url)
                    request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
                    
                    URLSession.shared.dataTask(with: request) { data, response, error in
                        if let error = error {
                            print("Error loading artwork: \(error.localizedDescription)")
                            return
                        }
                        
                        guard let data = data, let image = UIImage(data: data) else {
                            print("Failed to create image from artwork data")
                            return
                        }
                        
                        let artwork = MPMediaItemArtwork(boundsSize: CGSize(width: 500, height: 500)) { _ in image }
                        
                        DispatchQueue.main.async {
                            var updatedInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String: Any]()
                            updatedInfo[MPMediaItemPropertyArtwork] = artwork
                            MPNowPlayingInfoCenter.default().nowPlayingInfo = updatedInfo
                        }
                    }.resume()
                }
            }
        }
    }
    
    override func loadView() {
        // Create container view to respect safe area
        let containerView = UIView()
        containerView.backgroundColor = .systemBackground
        
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.allowsInlineMediaPlayback = true
        webConfiguration.mediaTypesRequiringUserActionForPlayback = []
        
        // Add message handler for receiving metadata from JavaScript
        webConfiguration.userContentController.add(self, name: "nowPlayingInfo")
        
        // Create web view with configuration
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add web view to container
        containerView.addSubview(webView)
        
        // Set container as the main view
        view = containerView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupWebViewConstraints()
        setupRemoteCommandCenter()
        setupWebView()
        loadContentRuleList()
        setupSilentModeObserver()
        startSilentModeCheckTimer()
    }
    
    private func setupWebViewConstraints() {
        guard let webView = webView else { return }
        
        // Constrain web view to safe area
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Ensure audio session is active when view appears
        activateAudioSession()
        startNowPlayingUpdateTimer()
        // Refresh Now Playing info when view appears
        refreshNowPlayingInfoIfNeeded()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        activateAudioSession()
        // Refresh Now Playing info after view appears
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.refreshNowPlayingInfoIfNeeded()
        }
    }
    
    func refreshNowPlayingInfoIfNeeded() {
        // If we have Now Playing info, refresh it to ensure it's visible
        guard MPNowPlayingInfoCenter.default().nowPlayingInfo != nil else { return }
        
        // Force extract and update Now Playing info
        executeJavaScript("""
            (function() {
                let title = '';
                let artist = '';
                const titleEl = document.querySelector('.title.style-scope.ytmusic-player-bar, .ytmusic-player-bar .title, [class*="title"][class*="ytmusic"]');
                const artistEl = document.querySelector('.byline.style-scope.ytmusic-player-bar, .ytmusic-player-bar .byline');
                if (titleEl) title = titleEl.textContent?.trim() || '';
                if (artistEl) artist = artistEl.textContent?.trim() || '';
                if (!title && document.title) {
                    title = document.title.replace(' - YouTube Music', '').trim();
                }
                
                const media = document.querySelector('video, audio');
                const duration = media ? (media.duration || 0) : 0;
                const currentTime = media ? (media.currentTime || 0) : 0;
                const isPlaying = media ? !media.paused : false;
                
                if (title) {
                    window.webkit.messageHandlers.nowPlayingInfo.postMessage({
                        title: title,
                        artist: artist || 'Unknown Artist',
                        artworkURL: '',
                        duration: duration,
                        currentTime: currentTime,
                        isPlaying: isPlaying
                    });
                    return true;
                }
                return false;
            })();
        """) { _, _ in }
    }
    
    private func updateNowPlayingInfoForNewTrack() {
        print("🔄 Updating Now Playing info for new track...")
        
        // Force extract and update Now Playing info with new track details
        executeJavaScript("""
            (function() {
                // Extract title and artist
                let title = '';
                let artist = '';
                let artworkURL = '';
                
                const titleEl = document.querySelector('.title.style-scope.ytmusic-player-bar, .ytmusic-player-bar .title, [class*="title"][class*="ytmusic"]');
                const artistEl = document.querySelector('.byline.style-scope.ytmusic-player-bar, .ytmusic-player-bar .byline');
                
                if (titleEl) title = titleEl.textContent?.trim() || '';
                if (artistEl) artist = artistEl.textContent?.trim() || '';
                
                if (!title && document.title) {
                    title = document.title.replace(' - YouTube Music', '').trim();
                }
                
                // Try to find artwork
                const artworkElement = document.querySelector('.image.style-scope.ytmusic-player-bar img, .ytmusic-player-bar img, .ytp-cued-thumbnail-overlay-image');
                if (artworkElement) {
                    artworkURL = artworkElement.src || artworkElement.getAttribute('src') || artworkElement.getAttribute('data-src') || '';
                }
                
                // Convert relative URLs to absolute
                if (artworkURL && !artworkURL.startsWith('http')) {
                    if (artworkURL.startsWith('//')) {
                        artworkURL = 'https:' + artworkURL;
                    } else if (artworkURL.startsWith('/')) {
                        artworkURL = 'https://music.youtube.com' + artworkURL;
                    }
                }
                
                // Get media element and its properties
                const media = document.querySelector('video, audio');
                let duration = 0;
                let currentTime = 0;
                let isPlaying = false;
                
                if (media) {
                    duration = media.duration || 0;
                    currentTime = media.currentTime || 0;
                    isPlaying = !media.paused;
                }
                
                if (title) {
                    window.webkit.messageHandlers.nowPlayingInfo.postMessage({
                        title: title,
                        artist: artist || 'Unknown Artist',
                        artworkURL: artworkURL,
                        duration: duration,
                        currentTime: currentTime,
                        isPlaying: isPlaying
                    });
                    return true;
                }
                return false;
            })();
        """) { [weak self] result, error in
            if let error = error {
                print("❌ Error updating Now Playing for new track: \(error)")
                // Retry after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self?.updateNowPlayingInfoForNewTrack()
                }
            } else if let success = result as? Bool, success {
                print("✅ Now Playing info updated for new track")
                // Verify duration is available, retry if not
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self?.verifyAndUpdateDurationIfNeeded()
                }
            } else {
                // If extraction failed, retry once more
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self?.updateNowPlayingInfoForNewTrack()
                }
            }
        }
    }
    
    private func verifyAndUpdateDurationIfNeeded() {
        // Check if duration is valid, if not, update again
        guard let nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        
        if let duration = nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] as? Double,
           duration <= 1.0 || duration.isNaN || duration.isInfinite {
            // Duration is invalid, try to get it again
            print("⚠️ Duration invalid, retrying update...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.updateNowPlayingInfoForNewTrack()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopNowPlayingUpdateTimer()
        stopSilentModeCheckTimer()
    }
    
    private func startNowPlayingUpdateTimer() {
        stopNowPlayingUpdateTimer()
        // Update every 2 seconds to keep info fresh
        nowPlayingUpdateTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.refreshNowPlayingInfo()
        }
    }
    
    private func stopNowPlayingUpdateTimer() {
        nowPlayingUpdateTimer?.invalidate()
        nowPlayingUpdateTimer = nil
    }
    
    private func refreshNowPlayingInfo() {
        // Only refresh if we already have info set
        guard var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo else { return }
        
        executeJavaScript("""
            (function() {
                const media = document.querySelector('video, audio');
                if (media) {
                    return {
                        duration: media.duration || 0,
                        currentTime: media.currentTime || 0,
                        isPlaying: !media.paused
                    };
                }
                return null;
            })();
        """) { (result: Any?, error: Error?) in
            guard let playbackState = result as? [String: Any] else { return }
            
            DispatchQueue.main.async {
                var info = nowPlayingInfo
                let duration = playbackState["duration"] as? Double ?? 0
                let currentTime = playbackState["currentTime"] as? Double ?? 0
                let isPlaying = playbackState["isPlaying"] as? Bool ?? false
                
                // Ensure duration is > 0 for Dynamic Island
                info[MPMediaItemPropertyPlaybackDuration] = duration > 0 ? duration : (info[MPMediaItemPropertyPlaybackDuration] as? Double ?? 180.0)
                info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
                // CRITICAL: Set playback rate to 1.0 when playing for Dynamic Island
                info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
                
                MPNowPlayingInfoCenter.default().nowPlayingInfo = info
            }
        }
    }
    
    private func updateNowPlayingPlaybackState() {
        // Update playback state in Now Playing info after play/pause from lock screen
        guard MPNowPlayingInfoCenter.default().nowPlayingInfo != nil else { return }
        
        executeJavaScript("""
            (function() {
                const media = document.querySelector('video, audio');
                if (media) {
                    return {
                        duration: media.duration || 0,
                        currentTime: media.currentTime || 0,
                        isPlaying: !media.paused
                    };
                }
                return null;
            })();
        """) { (result: Any?, error: Error?) in
            DispatchQueue.main.async {
                guard var info = MPNowPlayingInfoCenter.default().nowPlayingInfo,
                      let playbackState = result as? [String: Any] else { return }
                
                let duration = playbackState["duration"] as? Double ?? 0
                let currentTime = playbackState["currentTime"] as? Double ?? 0
                let isPlaying = playbackState["isPlaying"] as? Bool ?? false
                
                info[MPMediaItemPropertyPlaybackDuration] = duration > 0 ? duration : (info[MPMediaItemPropertyPlaybackDuration] as? Double ?? 1.0)
                info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
                info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
                
                MPNowPlayingInfoCenter.default().nowPlayingInfo = info
                print("Updated Now Playing playback state - Playing: \(isPlaying)")
            }
        }
    }
    
    private func activateAudioSession() {
        // Ensure audio session is active and configured for background playback
        do {
            let audioSession = AVAudioSession.sharedInstance()
            
            // Check current category and only set if different
            let currentCategory = audioSession.category
            let currentMode = audioSession.mode
            
            if currentCategory != .playback || currentMode != .default {
                try audioSession.setCategory(.playback, mode: .default, options: [.mixWithOthers, .allowAirPlay])
            }
            
            // Activate the session (this is safe to call multiple times)
            try audioSession.setActive(true, options: [])
        } catch {
            print("Failed to configure audio session: \(error.localizedDescription)")
            // Try with simpler options if the above fails
            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playback, mode: .default)
                try audioSession.setActive(true)
            } catch {
                print("Failed to configure audio session with fallback: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Silent Mode Detection
    
    private func setupSilentModeObserver() {
        // Observe route changes to detect silent mode
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioRouteChange),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }
    
    @objc private func handleAudioRouteChange(notification: Notification) {
        checkSilentModeAndHandle()
    }
    
    private func startSilentModeCheckTimer() {
        stopSilentModeCheckTimer()
        // Check every 0.5 seconds for silent mode changes
        silentModeCheckTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkSilentModeAndHandle()
        }
    }
    
    private func stopSilentModeCheckTimer() {
        silentModeCheckTimer?.invalidate()
        silentModeCheckTimer = nil
    }
    
    private func checkSilentModeAndHandle() {
        let audioSession = AVAudioSession.sharedInstance()
        let outputVolume = audioSession.outputVolume
        
        // Check if silent mode is enabled (volume is exactly 0)
        // Note: This will also trigger if user manually sets volume to 0, which is desired behavior
        let isSilentMode = outputVolume <= 0.0
        
        if isSilentMode && !isPausedDueToSilentMode {
            // Silent mode just enabled - pause the music
            print("🔇 Silent mode/volume 0 detected - pausing music")
            isPausedDueToSilentMode = true
            
            // Check if music is currently playing and pause it
            executeJavaScript("""
                (function() {
                    const media = document.querySelector('video, audio');
                    if (media && !media.paused) {
                        media.pause();
                        return true; // Was playing, now paused
                    }
                    return false; // Was already paused
                })();
            """) { [weak self] (result: Any?, error: Error?) in
                if let wasPlaying = result as? Bool {
                    self?.wasPlayingBeforeSilentMode = wasPlaying
                    if wasPlaying {
                        print("✅ Music was playing and has been paused due to silent mode")
                    }
                }
                // Update Now Playing info to show paused state
                DispatchQueue.main.async {
                    self?.updateNowPlayingPlaybackState()
                }
            }
        } else if !isSilentMode && isPausedDueToSilentMode {
            // Silent mode just disabled (volume restored)
            print("🔊 Silent mode disabled / volume restored")
            isPausedDueToSilentMode = false
            
            // Don't auto-resume - let the user manually resume if they want
            // This respects user intent better
            wasPlayingBeforeSilentMode = false
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        stopSilentModeCheckTimer()
        stopNowPlayingUpdateTimer()
    }
    
    private func setupWebView() {
        // Activate audio session
        activateAudioSession()
        
        // Load YouTube Music
        if let url = URL(string: "https://music.youtube.com") {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
    
    private func loadContentRuleList() {
        // Create content rule list for ad blocking
        // Block common ad domains
        let ruleList = """
        [
            {
                "trigger": {
                    "url-filter": ".*doubleclick\\.net.*"
                },
                "action": {
                    "type": "block"
                }
            },
            {
                "trigger": {
                    "url-filter": ".*googlesyndication\\.com.*"
                },
                "action": {
                    "type": "block"
                }
            },
            {
                "trigger": {
                    "url-filter": ".*googleadservices\\.com.*"
                },
                "action": {
                    "type": "block"
                }
            },
            {
                "trigger": {
                    "url-filter": ".*googletagservices\\.com.*"
                },
                "action": {
                    "type": "block"
                }
            },
            {
                "trigger": {
                    "url-filter": ".*googletagmanager\\.com.*"
                },
                "action": {
                    "type": "block"
                }
            },
            {
                "trigger": {
                    "url-filter": ".*adservice\\.google.*"
                },
                "action": {
                    "type": "block"
                }
            },
            {
                "trigger": {
                    "url-filter": ".*ads\\.youtube\\.com.*"
                },
                "action": {
                    "type": "block"
                }
            }
        ]
        """
        
        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: "AdBlockRules",
            encodedContentRuleList: ruleList
        ) { [weak self] contentRuleList, error in
            if let error = error {
                print("Error compiling content rule list: \(error)")
                // Continue with JavaScript-based blocking even if rule list fails
                self?.injectAdBlockingScript()
                return
            }
            
            guard let contentRuleList = contentRuleList else {
                self?.injectAdBlockingScript()
                return
            }
            self?.contentRuleList = contentRuleList
            
            // Add rule list to web view configuration
            self?.webView.configuration.userContentController.add(contentRuleList)
            
            // Inject JavaScript for enhanced ad blocking
            self?.injectAdBlockingScript()
        }
    }
    
    private func injectAdBlockingScript() {
        let adBlockingScript = """
        (function() {
            // Extract and send now playing info to native
            function extractNowPlayingInfo() {
                try {
                    // Try multiple selectors to find song title and artist
                    let title = '';
                    let artist = '';
                    let artworkURL = '';
                    
                    // Method 1: Look for YouTube Music player elements
                    const titleElement = document.querySelector('.title.style-scope.ytmusic-player-bar, .ytmusic-player-bar .title, [class*="title"][class*="ytmusic"], .ytp-title-link, .ytp-title');
                    const artistElement = document.querySelector('.byline.style-scope.ytmusic-player-bar, .ytmusic-player-bar .byline, [class*="byline"][class*="ytmusic"], .ytp-title-channel, .ytp-title-expanded-heading');
                    const artworkElement = document.querySelector('.image.style-scope.ytmusic-player-bar img, .ytmusic-player-bar img, .ytp-cued-thumbnail-overlay-image');
                    
                    if (titleElement) {
                        title = titleElement.textContent?.trim() || titleElement.getAttribute('title') || '';
                    }
                    
                    if (artistElement) {
                        artist = artistElement.textContent?.trim() || artistElement.getAttribute('title') || '';
                    }
                    
                    // Try multiple methods to find artwork
                    if (artworkElement) {
                        artworkURL = artworkElement.src || artworkElement.getAttribute('src') || artworkElement.getAttribute('data-src') || '';
                    }
                    
                    // Method 2: Try to find artwork from video thumbnail
                    if (!artworkURL && video) {
                        const videoPoster = video.getAttribute('poster');
                        if (videoPoster) {
                            artworkURL = videoPoster;
                        }
                    }
                    
                    // Method 3: Look for artwork in player bar image containers
                    if (!artworkURL) {
                        const imageContainers = document.querySelectorAll('ytmusic-player-bar img, .ytmusic-player-bar img, [class*="image"] img, [class*="thumbnail"] img, [class*="artwork"] img');
                        for (let img of imageContainers) {
                            const src = img.src || img.getAttribute('src') || img.getAttribute('data-src') || '';
                            if (src && (src.includes('i.ytimg.com') || src.includes('ytimg.com') || src.includes('googleusercontent.com'))) {
                                artworkURL = src;
                                break;
                            }
                        }
                    }
                    
                    // Method 4: Try to extract from background-image CSS
                    if (!artworkURL) {
                        const styleElements = document.querySelectorAll('[style*="background-image"], [style*="backgroundImage"]');
                        for (let el of styleElements) {
                            const style = el.getAttribute('style') || '';
                            const match = style.match(/url\\(['"]?([^'"]+)['"]?\\)/);
                            if (match && match[1]) {
                                artworkURL = match[1];
                                break;
                            }
                        }
                    }
                    
                    // Method 5: Try to find in yt-img-shadow or thumbnail elements
                    if (!artworkURL) {
                        const ytImgShadow = document.querySelector('yt-img-shadow img, ytmusic-thumbnail-renderer img');
                        if (ytImgShadow) {
                            artworkURL = ytImgShadow.src || ytImgShadow.getAttribute('src') || '';
                        }
                    }
                    
                    // Convert relative URLs to absolute
                    if (artworkURL && !artworkURL.startsWith('http')) {
                        if (artworkURL.startsWith('//')) {
                            artworkURL = 'https:' + artworkURL;
                        } else if (artworkURL.startsWith('/')) {
                            artworkURL = 'https://music.youtube.com' + artworkURL;
                        } else {
                            artworkURL = 'https://music.youtube.com/' + artworkURL;
                        }
                    }
                    
                    // Method 2: Try to get from video element
                    const video = document.querySelector('video');
                    if (video && !title) {
                        const videoTitle = video.getAttribute('title') || '';
                        if (videoTitle) {
                            const parts = videoTitle.split(' - ');
                            if (parts.length >= 2) {
                                artist = parts[0].trim();
                                title = parts.slice(1).join(' - ').trim();
                            } else {
                                title = videoTitle;
                            }
                        }
                    }
                    
                    // Method 3: Look for metadata in page title
                    if (!title && document.title) {
                        const pageTitle = document.title;
                        if (pageTitle.includes(' - ')) {
                            const parts = pageTitle.split(' - ');
                            if (parts.length >= 2) {
                                title = parts[0].trim();
                                artist = parts.slice(1).join(' - ').trim();
                            }
                        } else {
                            title = pageTitle.replace(' - YouTube Music', '').trim();
                        }
                    }
                    
                    // Method 4: Try to find in player bar
                    if (!title || !artist) {
                        const playerBar = document.querySelector('ytmusic-player-bar, .ytmusic-player-bar');
                        if (playerBar) {
                            const titleEl = playerBar.querySelector('[class*="title"], .title');
                            const artistEl = playerBar.querySelector('[class*="byline"], .byline, [class*="artist"]');
                            
                            if (titleEl && !title) {
                                title = titleEl.textContent?.trim() || '';
                            }
                            if (artistEl && !artist) {
                                artist = artistEl.textContent?.trim() || '';
                            }
                        }
                    }
                    
                    // Send to native if we have at least a title
                    if (title) {
                        console.log('Extracted Now Playing Info:', { title, artist, artworkURL });
                        window.webkit.messageHandlers.nowPlayingInfo.postMessage({
                            title: title,
                            artist: artist || 'Unknown Artist',
                            artworkURL: artworkURL || ''
                        });
                    }
                } catch(e) {
                    console.log('Error extracting now playing info:', e);
                }
            }
            
            // Block ad-related elements
            function removeAds() {
                if (!document.body) return;
                
                // Remove YouTube-specific ad containers
                const youtubeAdSelectors = [
                    '.ytp-ad-module',
                    '.ytp-ad-overlay-container',
                    '.ytp-ad-overlay-close-button',
                    '.ytp-ad-text',
                    '.ytp-ad-skip-button',
                    '.ad-showing',
                    '.ad-interrupting',
                    '[class*="ad-"]',
                    '[id*="ad-"]',
                    '[class*="Ad-"]',
                    '[id*="Ad-"]'
                ];
                
                youtubeAdSelectors.forEach(selector => {
                    try {
                        document.querySelectorAll(selector).forEach(el => {
                            // Don't remove video elements themselves
                            if (el && el.tagName !== 'VIDEO' && !el.closest('video')) {
                                el.style.display = 'none';
                                el.remove();
                            }
                        });
                    } catch(e) {}
                });
                
                // Remove ad iframes
                document.querySelectorAll('iframe').forEach(iframe => {
                    try {
                        const src = iframe.src || '';
                        if (src.includes('doubleclick') || 
                            src.includes('googlesyndication') || 
                            src.includes('googleadservices') ||
                            src.includes('adservice') ||
                            src.includes('/ads/') ||
                            src.includes('advertising')) {
                            iframe.remove();
                        }
                    } catch(e) {}
                });
                
                // Remove ad-related scripts
                document.querySelectorAll('script').forEach(script => {
                    try {
                        const src = script.src || '';
                        const content = script.textContent || '';
                        if (src.includes('doubleclick') || 
                            src.includes('googlesyndication') ||
                            src.includes('googleadservices') ||
                            content.includes('doubleclick') ||
                            content.includes('googlesyndication')) {
                            script.remove();
                        }
                    } catch(e) {}
                });
            }
            
            // Track if user manually paused - CRITICAL to prevent auto-resume
            let userManuallyPaused = false;
            let pauseTime = 0;
            const PAUSE_RESET_DELAY = 5000; // 5 seconds - after this, allow background resume protection
            
            // Keep playback active in background (but NEVER auto-resume if user paused)
            function keepPlaybackActive() {
                try {
                    // Prevent page visibility API from pausing playback
                    Object.defineProperty(document, 'hidden', {
                        get: function() { return false; },
                        configurable: true
                    });
                    
                    Object.defineProperty(document, 'visibilityState', {
                        get: function() { return 'visible'; },
                        configurable: true
                    });
                    
                    // Override visibility change events
                    const originalAddEventListener = document.addEventListener;
                    document.addEventListener = function(type, listener, options) {
                        if (type === 'visibilitychange') {
                            return; // Block visibility change listeners
                        }
                        return originalAddEventListener.call(this, type, listener, options);
                    };
                    
                    // Check current play state
                    const media = document.querySelector('video, audio');
                    if (media) {
                        const isPlaying = !media.paused;
                        const timeSincePause = Date.now() - pauseTime;
                        
                        // If user manually paused recently, NEVER auto-resume
                        if (userManuallyPaused && timeSincePause < PAUSE_RESET_DELAY) {
                            // User paused, respect it - do NOT resume
                            return;
                        }
                        
                        // If paused for longer than reset delay, clear the flag
                        // (allows normal background protection to work)
                        if (userManuallyPaused && timeSincePause >= PAUSE_RESET_DELAY) {
                            userManuallyPaused = false;
                        }
                    }
                    
                    // Prevent blur events from pausing playback (only if user didn't pause)
                    window.addEventListener('blur', function(e) {
                        if (!userManuallyPaused) {
                            e.stopImmediatePropagation();
                        }
                    }, true);
                    
                    // Prevent pagehide from pausing (only if user didn't pause)
                    window.addEventListener('pagehide', function(e) {
                        if (!userManuallyPaused) {
                            e.stopImmediatePropagation();
                        }
                    }, true);
                } catch(e) {
                    console.log('Error in keepPlaybackActive:', e);
                }
            }
            
            // Track user pause actions - mark as user-initiated
            document.addEventListener('pause', function(e) {
                if (e.target.tagName === 'VIDEO' || e.target.tagName === 'AUDIO') {
                    // Check if this was a user-initiated pause
                    if (e.isTrusted) {
                        userManuallyPaused = true;
                        pauseTime = Date.now();
                        console.log('User manually paused - will not auto-resume');
                    }
                }
            }, true);
            
            // Track user play actions - clear pause flag when user plays
            document.addEventListener('play', function(e) {
                if (e.target.tagName === 'VIDEO' || e.target.tagName === 'AUDIO') {
                    // User started playing, clear the pause flag
                    if (e.isTrusted) {
                        userManuallyPaused = false;
                        pauseTime = 0;
                        console.log('User manually played - background protection active');
                    }
                }
            }, true);
            
            // Also track pause from lock screen controls via message
            // This is called when pause command is executed
            if (window.webkit && window.webkit.messageHandlers) {
                // Store original postMessage to intercept pause commands
                const originalPostMessage = window.webkit.messageHandlers.nowPlayingInfo.postMessage;
            }
            
            // Run immediately if DOM is ready
            if (document.body) {
                removeAds();
                keepPlaybackActive();
            } else {
                document.addEventListener('DOMContentLoaded', function() {
                    removeAds();
                    keepPlaybackActive();
                });
            }
            
            // Run periodically
            setInterval(function() {
                removeAds();
                keepPlaybackActive();
                extractNowPlayingInfo();
            }, 1000);
            
            // Run on DOM changes
            if (document.body) {
                const observer = new MutationObserver(function() {
                    removeAds();
                    keepPlaybackActive();
                    extractNowPlayingInfo();
                });
                observer.observe(document.body, {
                    childList: true,
                    subtree: true,
                    attributes: true
                });
            }
            
            // Extract info when page loads
            if (document.body) {
                extractNowPlayingInfo();
            } else {
                document.addEventListener('DOMContentLoaded', extractNowPlayingInfo);
            }
            
            // Also listen for video play events - CRITICAL for Dynamic Island
            document.addEventListener('play', function(e) {
                if (e.target.tagName === 'VIDEO' || e.target.tagName === 'AUDIO') {
                    const media = e.target;
                    setTimeout(function() {
                        extractNowPlayingInfo();
                        // Force update Now Playing when playback starts
                        window.webkit.messageHandlers.nowPlayingInfo.postMessage({
                            playbackStarted: true,
                            isPlaying: !media.paused,
                            currentTime: media.currentTime || 0,
                            duration: media.duration || 0
                        });
                    }, 300);
                }
            }, true);
            
            // Listen for timeupdate to keep Now Playing info fresh
            document.addEventListener('timeupdate', function(e) {
                if (e.target.tagName === 'VIDEO' || e.target.tagName === 'AUDIO') {
                    const media = e.target;
                    // Update more frequently when playing
                    if (!media.paused) {
                        extractNowPlayingInfo();
                    }
                }
            }, true);
            
            // Also listen for playing event (when media actually starts)
            document.addEventListener('playing', function(e) {
                if (e.target.tagName === 'VIDEO' || e.target.tagName === 'AUDIO') {
                    extractNowPlayingInfo();
                    window.webkit.messageHandlers.nowPlayingInfo.postMessage({
                        playbackStarted: true
                    });
                }
            }, true);
            
            // Block ad-related network requests via fetch
            const originalFetch = window.fetch;
            window.fetch = function(...args) {
                const url = args[0]?.toString() || '';
                if (url.includes('doubleclick') || 
                    url.includes('googlesyndication') || 
                    url.includes('googleadservices') ||
                    url.includes('adservice') ||
                    url.includes('/ads/') ||
                    url.includes('advertising')) {
                    return Promise.reject(new Error('Ad blocked'));
                }
                return originalFetch.apply(this, args);
            };
            
            // Block XMLHttpRequest to ad URLs
            const originalOpen = XMLHttpRequest.prototype.open;
            XMLHttpRequest.prototype.open = function(method, url, ...rest) {
                if (typeof url === 'string' && (
                    url.includes('doubleclick') || 
                    url.includes('googlesyndication') || 
                    url.includes('googleadservices') ||
                    url.includes('adservice') ||
                    url.includes('/ads/') ||
                    url.includes('advertising')
                )) {
                    return;
                }
                return originalOpen.apply(this, [method, url, ...rest]);
            };
        })();
        """
        
        // Inject at document start for better coverage
        let script = WKUserScript(
            source: adBlockingScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        
        webView.configuration.userContentController.addUserScript(script)
        
        // Also inject at document end as backup
        let scriptEnd = WKUserScript(
            source: adBlockingScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        
        webView.configuration.userContentController.addUserScript(scriptEnd)
    }
}

// MARK: - WKNavigationDelegate
extension MusicViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("Page loaded successfully")
        // Ensure audio session is active
        activateAudioSession()
        // Inject ad blocking script again after page load
        injectAdBlockingScript()
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // Block navigation to ad URLs
        if let url = navigationAction.request.url?.absoluteString {
            if url.contains("doubleclick") ||
               url.contains("googlesyndication") ||
               url.contains("googleadservices") ||
               url.contains("adservice") ||
               url.contains("/ads/") {
                decisionHandler(.cancel)
                return
            }
        }
        decisionHandler(.allow)
    }
}

// MARK: - WKUIDelegate
extension MusicViewController: WKUIDelegate {
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        // Open links in the same web view
        if navigationAction.targetFrame == nil {
            webView.load(navigationAction.request)
        }
        return nil
    }
}

// MARK: - WKScriptMessageHandler
extension MusicViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "nowPlayingInfo" {
            guard let body = message.body as? [String: Any] else {
                print("Failed to parse message body")
                return
            }
            
            // Check if this is a playback started notification
            if let playbackStarted = body["playbackStarted"] as? Bool, playbackStarted {
                print("🎵 Playback started - updating Now Playing for Dynamic Island")
                
                // Ensure audio session is active
                activateAudioSession()
                
                // Force extract and update Now Playing info
                executeJavaScript("""
                    (function() {
                        let title = '';
                        let artist = '';
                        const titleEl = document.querySelector('.title.style-scope.ytmusic-player-bar, .ytmusic-player-bar .title, [class*="title"][class*="ytmusic"]');
                        const artistEl = document.querySelector('.byline.style-scope.ytmusic-player-bar, .ytmusic-player-bar .byline');
                        if (titleEl) title = titleEl.textContent?.trim() || '';
                        if (artistEl) artist = artistEl.textContent?.trim() || '';
                        if (!title && document.title) {
                            title = document.title.replace(' - YouTube Music', '').trim();
                        }
                        
                        const media = document.querySelector('video, audio');
                        const duration = media ? (media.duration || 0) : 0;
                        const currentTime = media ? (media.currentTime || 0) : 0;
                        const isPlaying = media ? !media.paused : false;
                        
                        if (title) {
                            window.webkit.messageHandlers.nowPlayingInfo.postMessage({
                                title: title,
                                artist: artist || 'Unknown Artist',
                                artworkURL: '',
                                duration: duration,
                                currentTime: currentTime,
                                isPlaying: isPlaying
                            });
                        }
                    })();
                """) { _, _ in }
                return
            }
            
            guard let title = body["title"] as? String else {
                print("Failed to extract title from message")
                return
            }
            
            let artist = body["artist"] as? String ?? "Unknown Artist"
            let artworkURL = body["artworkURL"] as? String
            
            // Get playback state from message if available
            let duration = body["duration"] as? Double
            let currentTime = body["currentTime"] as? Double
            let isPlaying = body["isPlaying"] as? Bool
            
            print("🎵 Received Now Playing Info - Title: \(title), Artist: \(artist)")
            
            DispatchQueue.main.async { [weak self] in
                self?.updateNowPlayingInfo(
                    title: title,
                    artist: artist,
                    artworkURL: artworkURL,
                    duration: duration,
                    currentTime: currentTime,
                    isPlaying: isPlaying
                )
            }
        }
    }
}
