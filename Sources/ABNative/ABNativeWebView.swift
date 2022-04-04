//
//  WebView.swift
//  Alta Associations
//
//  Created by Jakub Zolcik on 17/03/2021.
//

import Combine
import Foundation
import SwiftUI
import UIKit
import WebKit

struct ABNativeWebView: UIViewRepresentable {
    public let nativeApp: ABNativeApp
    
    init(_ nativeApp: ABNativeApp) {
        self.nativeApp = nativeApp
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        
        let configuration = WKWebViewConfiguration()
        configuration.userContentController.add(self.makeCoordinator(), name: "abNative_IOS")
        configuration.defaultWebpagePreferences = preferences
        
        let webView = WKWebView(frame: CGRect.zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.isScrollEnabled = true
        
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        /* Debug */
//        if let url = URL(string: "http://192.168.1.168/ios-dev") {
//            webView.load(URLRequest(url: url))
//        }
        /* / Debug */
        
        /* Release */
        let base_Url = Bundle.main.url(forResource: "WebApp", withExtension: nil)
        let header_Url = Bundle.main.url(forResource: "cache/abWeb/web/header.html", withExtension: nil, subdirectory: "WebApp")
        let index_Url = Bundle.main.url(forResource: "index.base.html", withExtension: nil, subdirectory: "WebApp")

        let base = base_Url?.absoluteString.replacingOccurrences(of: "file:///", with: "/")

        do {
            var header = try String(contentsOf: header_Url!, encoding: .utf8)
            header = header.replacingOccurrences(of: "{{base}}", with: base!)

            var debug = "false";
            if (ProcessInfo().environment["BuildType_Debug"] != nil) {
                debug = "true";
            }

            var index = try String(contentsOf: index_Url!, encoding: .utf8)
            index = index.replacingOccurrences(of: "{{base}}", with: base!)
            index = index.replacingOccurrences(of: "{{header}}", with: header)
            index = index.replacingOccurrences(of: "{{debug}}", with: debug)

            webView.loadHTMLString(index, baseURL: base_Url)
        } catch {
            print("Cannot read header: \(error)")
        }
        /* / Release */
        
//        print("Test: " + Bundle.main.bundleURL.absoluteString)
        
//        let url = Bundle.main.url(forResource: "index.base", withExtension: "html", subdirectory: "WebApp")
        
//        print("Testing \(url)")
//        let request = URLRequest(url: url!)
//        webView.load(request)
    }
    
    
    class Coordinator : NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        private var parent: ABNativeWebView
        private var evaluateJS_Subscriber: AnyCancellable? = nil
        
        init(_ uiWebView: ABNativeWebView) {
            self.parent = uiWebView
        }
        
        deinit {
            self.evaluateJS_Subscriber?.cancel()
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let args = message.body as? [String: AnyObject],
                  let messageType = args["messageType"] as? String else {
                assert(true, "Cannot process script message.")
                return
            }
            
            if (messageType == "callNative") {
                guard let actionId = args["actionId"] as? Int,
                      let actionSetName = args["actionsSetName"] as? String,
                      let actionName = args["actionName"] as? String,
                      let actionArgs = args["actionArgs"] as? [String: AnyObject] else {
                    self.parent.nativeApp.errorNative("Cannot parse 'callNative' args.")
                    return
                }
                
                self.parent.nativeApp.callNative(actionId, actionSetName, actionName, actionArgs)
            } else if (messageType == "onWebResult") {
                guard let actionId = args["actionId"] as? Int,
                      let result = args["result"] as? [String: AnyObject] else {
                    self.parent.nativeApp.errorNative("Cannot parse 'onWebResult' result.")
                    return
                }
                
                self.parent.nativeApp.onWebResult(actionId, result)
            }
        }
        
        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            
        }
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            self.evaluateJS_Subscriber = parent.nativeApp.evaluateJS.receive(on: RunLoop.main).sink(receiveValue: { value in
                webView.evaluateJavaScript(value) { (result, error) in

                }
            })
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {

        }
        
    }
    
}
