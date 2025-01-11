
import Combine
import Foundation
import SwiftUI
import UIKit
import WebKit

public struct ABNativeWebView: UIViewRepresentable {
    
    public let nativeApp: ABNativeApp
    public let webView: WKWebView
    
    private let debugUrl: String?
    
    private let webAppSubdirectory: String
    
    
    public init(_ nativeApp: ABNativeApp, debugUrl: String?, webAppSubdirectory: String) {
        self.nativeApp = nativeApp
        self.debugUrl = debugUrl
        self.webAppSubdirectory = webAppSubdirectory
        
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        
//        let controler = WKUserContentController()
//        controler.add(self, name: "error")
        
        let configuration = WKWebViewConfiguration()
//        configuration.userContentController.add(self.makeCoordinator(), name: "abNative_IOS")
        configuration.defaultWebpagePreferences = preferences
        
        self.webView = WKWebView(frame: CGRect.zero, configuration: configuration)
        if #available(iOS 16.4, *) {
            self.webView.isInspectable = true
        }
        self.webView.allowsBackForwardNavigationGestures = true
        self.webView.scrollView.isScrollEnabled = true
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    public func makeUIView(context: Context) -> WKWebView {
        self.webView.configuration.userContentController.add(self.makeCoordinator(), name: "abNative_IOS")
        self.webView.navigationDelegate = context.coordinator
        
        return self.webView
    }
    
    public func reload() {
        /* Debug */
        if (debugUrl != nil) {
            if let url = URL(string: debugUrl ?? "") {
                webView.load(URLRequest(url: url, cachePolicy: URLRequest.CachePolicy.reloadIgnoringLocalAndRemoteCacheData))
            } else {
                print("ABNativeWebView -> Cannot parse 'debugUrl': \(debugUrl)")
            }
        /* Release */
        } else {
            let base_Url = Bundle.main.url(forResource: webAppSubdirectory, withExtension: nil)
            let header_Url = Bundle.main.url(forResource: "cache/abWeb/web/header", withExtension: "html", subdirectory: webAppSubdirectory)
            let header_Scripts_Url = Bundle.main.url(forResource: "cache/abWeb/web/header_Scripts", withExtension: "html", subdirectory: webAppSubdirectory)
            let postBody_Url = Bundle.main.url(forResource: "cache/abWeb/web/postBody.html", withExtension: nil, subdirectory: webAppSubdirectory)
            let postBody_Scripts_Url = Bundle.main.url(forResource: "cache/abWeb/web/postBody_Scripts.html", withExtension: nil, subdirectory: webAppSubdirectory)
            let index_Url = Bundle.main.url(forResource: "index.base.html", withExtension: nil, subdirectory: webAppSubdirectory)

            let base = base_Url?.absoluteString.replacingOccurrences(of: "file:///", with: "/")
            
            do {
                var header = try String(contentsOf: header_Url!, encoding: .utf8)
                header += try String(contentsOf: header_Scripts_Url!, encoding: .utf8)
                header = header.replacingOccurrences(of: "{{base}}", with: base!)
                
                var postBody = try String(contentsOf: postBody_Url!, encoding: .utf8)
                postBody += try String(contentsOf: postBody_Scripts_Url!, encoding: .utf8)
                postBody = postBody.replacingOccurrences(of: "{{base}}", with: base!)

                var debug = "false";
                if (ProcessInfo().environment["BuildType_Debug"] != nil) {
                    debug = "true";
                }

                var index = try String(contentsOf: index_Url!, encoding: .utf8)
                index = index.replacingOccurrences(of: "{{base}}", with: base!)
                index = index.replacingOccurrences(of: "{{header}}", with: header)
                index = index.replacingOccurrences(of: "{{postBody}}", with: postBody)
                index = index.replacingOccurrences(of: "{{debug}}", with: debug)

                self.webView.loadHTMLString(index, baseURL: base_Url)
            } catch {
                print("ABNativeWebView -> Cannot read header: \(error)")
            }
        }
    }
    
    public func updateUIView(_ webView: WKWebView, context: Context) {
        self.reload()
        
//        print("Test: " + Bundle.main.bundleURL.absoluteString)
        
//        let url = Bundle.main.url(forResource: "index.base", withExtension: "html", subdirectory: webAppSubdirectory)
        
//        print("Testing \(url)")
//        let request = URLRequest(url: url!)
//        webView.load(request)
    }
    
    
    public class Coordinator : NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        private var parent: ABNativeWebView
        private var evaluateJS_Subscriber: AnyCancellable? = nil
        
        public init(_ uiWebView: ABNativeWebView) {
            self.parent = uiWebView
        }
        
        deinit {
            self.evaluateJS_Subscriber?.cancel()
        }
        
        public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let args = message.body as? [String: AnyObject],
                  let messageType = args["messageType"] as? String else {
                parent.nativeApp.errorMessage("ABNativeWebView Coordinator Error -> Cannot process script message.")
                return
            }
            
            if (messageType == "callNative") {
                guard let actionId = args["actionId"] as? Int,
                      let actionSetName = args["actionsSetName"] as? String,
                      let actionName = args["actionName"] as? String else {
                    parent.nativeApp.errorMessage("ABNativeWebView Coordinator Error -> Cannot parse 'callNative' args.")
                    return
                }
                
                var actionArgs: [String: AnyObject]?
                if (args["actionArgs"] is NSNull) {
                    actionArgs = nil
                } else {
                    guard let v = args["actionArgs"] as? [String: AnyObject] else {
                        parent.nativeApp.errorMessage("ABNativeWebView Coordinator Error -> Cannot parse 'callNative' action args.")
                        return
                    }
                    actionArgs = v
                }
                
                self.parent.nativeApp.callNative(actionId, actionSetName, actionName, actionArgs)
            } else if (messageType == "onWebResult") {
                guard let actionId = args["actionId"] as? Int else {
                    parent.nativeApp.errorMessage("ABNativeWebView Coordinator Error -> Cannot parse 'onWebResult' result -> Cannot get 'actionId'.")
                    return
                }
                
                guard args["error"] is NSNull else {
                    guard let error = args["error"] as? String else {
                        parent.nativeApp.errorMessage("ABNativeWebView Coordinator Error -> Cannot parse 'onWebResult' result -> Cannot get 'error'.")
                        return
                    }
                    parent.nativeApp.onWebResult(actionId, nil, error)
                    return
                }
                
                if args["result"] is NSNull {
                    parent.nativeApp.onWebResult(actionId, nil, nil)
                    return
                } else {
                    guard let result = args["result"] as? [String: AnyObject] else {
                        parent.nativeApp.errorMessage("ABNativeWebView Coordinator Error -> Cannot parse 'onWebResult' result -> Cannot get 'result'.")
                        return
                    }
                    
                    parent.nativeApp.onWebResult(actionId, result, nil)
                }
            } else if (messageType == "onError") {
                guard let error = args["error"] as? [String: AnyObject] else {
                    parent.nativeApp.errorMessage("ABNativeWebView Coordinator Error -> Cannot parse JS Error.")
                    return
                }
                
                guard let errorMessage = error["message"] as? String,
                      let errorUrl = error["url"] as? String,
                      let errorStack = error["stack"] as? String else {
                    parent.nativeApp.errorMessage("ABNativeWebView Coordinator Error -> Cannot read JS Error properties.")
                    return
                }
                parent.nativeApp.errorMessage("ABNativeWebView Coordinator Error -> JS Error: \(errorStack ?? "unknown")")
            } else if (messageType == "reload") {
                parent.reload()
            } else if (messageType == "webViewInitialized") {
                parent.nativeApp.webViewInitialized()
            }
        }
        
        public func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        }
        
        public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            self.evaluateJS_Subscriber = parent.nativeApp.evaluateJS.receive(on: RunLoop.main).sink(receiveValue: { value in
                webView.evaluateJavaScript(value) { (result, error) in

                }
            })
        }
        
        public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
            print("ABNativeWebView -> Error loading: '" + (parent.debugUrl ?? "<local>") + "' -> \(error)")
        }
        
        public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
            print("ABNativeWebView -> Error loading: '" + (parent.debugUrl ?? "<local>") + "' -> \(error)")
        }
        
    }

}
