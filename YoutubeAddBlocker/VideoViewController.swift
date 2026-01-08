//
//  VideoViewController.swift
//  YoutubeAddBlocker
//
//  Created by Karthik Solleti on 08/01/26.
//

import UIKit
import WebKit
import AVFoundation
import AVKit

class VideoViewController: UIViewController {
    
    private var webView: WKWebView!
    private var contentRuleList: WKContentRuleList?
    
    
    override func loadView() {
        // Create container view to respect safe area
        let containerView = UIView()
        containerView.backgroundColor = .systemBackground
        
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.allowsInlineMediaPlayback = true
        webConfiguration.mediaTypesRequiringUserActionForPlayback = []
        webConfiguration.allowsPictureInPictureMediaPlayback = true
        
        // Enable PIP for all media types
        if #available(iOS 15.0, *) {
            webConfiguration.defaultWebpagePreferences.allowsContentJavaScript = true
        }
        
        // Configure for background rendering (important for PIP)
        webConfiguration.processPool = WKProcessPool()
        
        // Add message handler for PIP control
        webConfiguration.userContentController.add(self, name: "pipControl")
        
        // Create web view with configuration
        webView = WKWebView(frame: .zero, configuration: webConfiguration)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.translatesAutoresizingMaskIntoConstraints = false
        
        // Enable background rendering for PIP
        webView.configuration.allowsInlineMediaPlayback = true
        
        // Add web view to container
        containerView.addSubview(webView)
        
        // Set container as the main view
        view = containerView
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupWebViewConstraints()
        configureWebViewScrolling()
        setupWebView()
        loadContentRuleList()
    }
    
    private func configureWebViewScrolling() {
        // Ensure scroll view allows all gestures
        webView.scrollView.isScrollEnabled = true
        webView.scrollView.bounces = true
        webView.scrollView.alwaysBounceVertical = true
        webView.scrollView.alwaysBounceHorizontal = false
        
        // Allow swipe down gestures
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        
        // Don't block any gestures
        webView.scrollView.canCancelContentTouches = true
        webView.scrollView.delaysContentTouches = false
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
        // Only activate audio session once when view appears
        activateAudioSession()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Inject ad blocking script and enable PIP after view appears
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.injectAdBlockingScript()
            self.enablePictureInPictureSupport()
            self.injectBackgroundPIPSupport()
        }
    }
    
    private func setupWebView() {
        // Load YouTube
        if let url = URL(string: "https://www.youtube.com") {
            let request = URLRequest(url: url)
            webView.load(request)
        }
    }
    
    private func activateAudioSession() {
        // Only configure audio session if not already configured correctly
        let audioSession = AVAudioSession.sharedInstance()
        let currentCategory = audioSession.category
        let currentMode = audioSession.mode
        
        // Check if already configured correctly
        if currentCategory == .playback && currentMode == .moviePlayback {
            // Already configured, just ensure it's active
            if !audioSession.isOtherAudioPlaying {
                do {
                    try audioSession.setActive(true, options: [])
                } catch {
                    // Silently fail if already active
                }
            }
            return
        }
        
        do {
            // Use moviePlayback mode for better video/PIP support
            try audioSession.setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers, .allowAirPlay])
            
            // Only activate if not already active or if other audio is not playing
            if !audioSession.isOtherAudioPlaying {
                try audioSession.setActive(true, options: [])
            }
        } catch {
            print("Failed to configure audio session: \(error.localizedDescription)")
            // Try with simpler configuration
            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playback, mode: .moviePlayback)
                if !audioSession.isOtherAudioPlaying {
                    try audioSession.setActive(true)
                }
            } catch {
                // Silently fail - audio session might already be configured by system
                print("Failed to configure audio session with fallback: \(error.localizedDescription)")
            }
        }
    }
    
    private func loadContentRuleList() {
        // Create content rule list for ad blocking
        let ruleListSource = """
        [{
            "trigger": {
                "url-filter": ".*",
                "if-domain": ["*doubleclick.net*", "*googlesyndication.com*", "*googleadservices.com*", "*adservice.google.*"]
            },
            "action": {
                "type": "block"
            }
        }]
        """
        
        WKContentRuleListStore.default().compileContentRuleList(
            forIdentifier: "AdBlockingRules",
            encodedContentRuleList: ruleListSource
        ) { [weak self] ruleList, error in
            if let error = error {
                print("Failed to compile content rule list: \(error)")
                return
            }
            
            guard let ruleList = ruleList else { return }
            self?.contentRuleList = ruleList
            
            DispatchQueue.main.async {
                let configuration = self?.webView.configuration
                configuration?.userContentController.add(ruleList)
            }
        }
    }
    
    private func injectAdBlockingScript() {
        let adBlockingScript = """
        (function() {
            // Ensure touch events and gestures are not blocked
            document.addEventListener('touchstart', function(e) {
                // Allow all touch events
            }, { passive: true });
            
            document.addEventListener('touchmove', function(e) {
                // Allow all touch move events
            }, { passive: true });
            
            // Remove ad-related elements
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
                    '[id*="Ad-"]',
                    '.ytp-ad-overlay-container',
                    '.ytp-ad-skip-button-container',
                    '.ytp-ad-overlay-ad-info',
                    '.ytp-ad-overlay-image',
                    '.ytp-ad-text',
                    '.ytp-ad-overlay-close-button'
                ];
                
                youtubeAdSelectors.forEach(selector => {
                    try {
                        document.querySelectorAll(selector).forEach(el => {
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
            }
            
            // Run ad removal on page load
            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', removeAds);
            } else {
                removeAds();
            }
            
            // Continuously monitor and remove ads
            setInterval(removeAds, 1000);
            
            // Use MutationObserver to remove ads as they appear
            const observer = new MutationObserver(function(mutations) {
                removeAds();
            });
            
            observer.observe(document.body, {
                childList: true,
                subtree: true
            });
            
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
                    url.includes('advertising'))) {
                    return;
                }
                return originalOpen.apply(this, [method, url, ...rest]);
            };
        })();
        """
        
        let script = WKUserScript(source: adBlockingScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        webView.configuration.userContentController.addUserScript(script)
    }
    
    private func enablePictureInPictureSupport() {
        // Inject JavaScript to enable PIP on video elements
        // YouTube videos need special handling for PIP
        let pipScript = """
        (function() {
            let pipEnabled = false;
            
            // Enable PIP on video elements (but don't auto-trigger)
            function enablePIP() {
                const videos = document.querySelectorAll('video');
                videos.forEach(video => {
                    // Ensure video has playsinline attribute for better PIP support
                    if (!video.hasAttribute('playsinline')) {
                        video.setAttribute('playsinline', 'true');
                    }
                    // Enable webkit-playsinline for iOS
                    if (!video.hasAttribute('webkit-playsinline')) {
                        video.setAttribute('webkit-playsinline', 'true');
                    }
                    
                    // Don't automatically trigger PIP - only enable it for manual use
                    // PIP will be triggered only when user clicks the PIP button
                });
            }
            
            // Function to add PIP button to YouTube player
            function addPIPButton() {
                // Try to find YouTube player controls
                const playerControls = document.querySelector('.ytp-chrome-bottom, .ytp-right-controls, .ytp-left-controls');
                if (playerControls && !document.getElementById('custom-pip-button')) {
                    const pipButton = document.createElement('button');
                    pipButton.id = 'custom-pip-button';
                    pipButton.className = 'ytp-button';
                    pipButton.innerHTML = '<svg width="24" height="24" viewBox="0 0 24 24" fill="white"><path d="M19 7h-8v6h8V7zm0-2c1.1 0 2 .9 2 2v6c0 1.1-.9 2-2 2h-8c-1.1 0-2-.9-2-2V7c0-1.1.9-2 2-2h8zM5 19h14v-2H5v2zm0-4h14v-2H5v2zm0-4h2v2H5v-2zm0-4h2v2H5V7z"/></svg>';
                    pipButton.style.cssText = 'background: transparent; border: none; cursor: pointer; padding: 8px; margin: 0 4px;';
                    pipButton.title = 'Picture in Picture';
                    
                    pipButton.addEventListener('click', function(e) {
                        e.preventDefault();
                        e.stopPropagation();
                        const video = document.querySelector('video');
                        if (video) {
                            if (video.requestPictureInPicture) {
                                video.requestPictureInPicture().catch(function(err) {
                                    console.log('PIP request failed:', err);
                                });
                            } else if (video.webkitSetPresentationMode) {
                                try {
                                    video.webkitSetPresentationMode('picture-in-picture');
                                } catch(e) {
                                    console.log('WebKit PIP failed:', e);
                                }
                            }
                        }
                    });
                    
                    // Try to add to right controls first, then left, then bottom
                    const rightControls = document.querySelector('.ytp-right-controls');
                    if (rightControls) {
                        rightControls.insertBefore(pipButton, rightControls.firstChild);
                    } else {
                        const leftControls = document.querySelector('.ytp-left-controls');
                        if (leftControls) {
                            leftControls.appendChild(pipButton);
                        } else if (playerControls) {
                            playerControls.appendChild(pipButton);
                        }
                    }
                }
            }
            
            // Run on page load
            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', function() {
                    enablePIP();
                    setTimeout(addPIPButton, 2000);
                });
            } else {
                enablePIP();
                setTimeout(addPIPButton, 2000);
            }
            
            // Monitor for new video elements and player controls
            const observer = new MutationObserver(function(mutations) {
                enablePIP();
                addPIPButton();
            });
            
            if (document.body) {
                observer.observe(document.body, {
                    childList: true,
                    subtree: true
                });
            }
            
            // Re-enable PIP periodically
            setInterval(function() {
                enablePIP();
                addPIPButton();
            }, 3000);
        })();
        """
        
        let script = WKUserScript(source: pipScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        webView.configuration.userContentController.addUserScript(script)
    }
    
    func maintainPIPPlayback() {
        // Execute JavaScript to maintain playback
        // Don't activate audio session here to avoid conflicts
        executeJavaScript("""
            (function() {
                const video = document.querySelector('video');
                if (video && !video.paused) {
                    // Ensure video keeps playing
                    video.play().catch(function(err) {
                        console.log('Maintain PIP playback failed:', err);
                    });
                }
            })();
        """)
    }
    
    private func injectBackgroundPIPSupport() {
        // Inject script to prevent YouTube from pausing video when app goes to background
        // This is crucial for PIP to continue working
        let backgroundScript = """
        (function() {
            // Prevent page from detecting background state
            Object.defineProperty(document, 'hidden', { 
                get: function() { return false; }, 
                configurable: true 
            });
            
            Object.defineProperty(document, 'visibilityState', { 
                get: function() { return 'visible'; }, 
                configurable: true 
            });
            
            // Block visibilitychange events that might pause video
            const originalAddEventListener = document.addEventListener;
            document.addEventListener = function(type, listener, options) {
                if (type === 'visibilitychange') {
                    return; // Don't add visibilitychange listeners
                }
                return originalAddEventListener.call(this, type, listener, options);
            };
            
            // Prevent blur/pagehide events from pausing video
            window.addEventListener('blur', function(e) {
                e.stopImmediatePropagation();
            }, true);
            
            window.addEventListener('pagehide', function(e) {
                e.stopImmediatePropagation();
            }, true);
            
            // Keep video playing when app goes to background
            function maintainVideoPlayback() {
                const video = document.querySelector('video');
                if (video) {
                    // Ensure video doesn't pause automatically
                    video.addEventListener('pause', function(e) {
                        // Only prevent auto-pause, not user-initiated pauses
                        if (!e.isTrusted && video.paused) {
                            setTimeout(function() {
                                if (video.paused) {
                                    video.play().catch(function(err) {
                                        console.log('Auto-resume failed:', err);
                                    });
                                }
                            }, 100);
                        }
                    }, true);
                    
                    // Keep video playing if it was playing before
                    if (!video.paused) {
                        // Monitor and maintain playback
                        setInterval(function() {
                            if (video.paused && document.visibilityState === 'visible') {
                                video.play().catch(function(err) {
                                    // Silently fail - video might be legitimately paused
                                });
                            }
                        }, 2000);
                    }
                }
            }
            
            // Run when video is available
            if (document.readyState === 'loading') {
                document.addEventListener('DOMContentLoaded', maintainVideoPlayback);
            } else {
                maintainVideoPlayback();
            }
            
            // Also monitor for new video elements
            const observer = new MutationObserver(function(mutations) {
                maintainVideoPlayback();
            });
            
            if (document.body) {
                observer.observe(document.body, {
                    childList: true,
                    subtree: true
                });
            }
        })();
        """
        
        let script = WKUserScript(source: backgroundScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        webView.configuration.userContentController.addUserScript(script)
    }
    
    private func executeJavaScript(_ script: String, completion: ((Any?, Error?) -> Void)? = nil) {
        guard let webView = webView else {
            completion?(nil, NSError(domain: "VideoViewController", code: -1, userInfo: [NSLocalizedDescriptionKey: "WebView not available"]))
            return
        }
        
        webView.evaluateJavaScript(script, completionHandler: completion)
    }
}

// MARK: - WKNavigationDelegate
extension VideoViewController: WKNavigationDelegate {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        print("✅ Page loaded successfully")
        // Inject ad blocking script and enable PIP after page load
        injectAdBlockingScript()
        enablePictureInPictureSupport()
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // Block navigation to ad URLs
        if let url = navigationAction.request.url?.absoluteString {
            if url.contains("doubleclick") ||
               url.contains("googlesyndication") ||
               url.contains("googleadservices") ||
               url.contains("adservice") ||
               url.contains("/ads/") ||
               url.contains("advertising") {
                decisionHandler(.cancel)
                return
            }
        }
        decisionHandler(.allow)
    }
}

// MARK: - WKUIDelegate
extension VideoViewController: WKUIDelegate {
    // Handle any UI delegate methods if needed
}

// MARK: - WKScriptMessageHandler
extension VideoViewController: WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "pipControl" {
            // Handle PIP control messages if needed
            print("PIP control message received: \(message.body)")
        }
    }
}
