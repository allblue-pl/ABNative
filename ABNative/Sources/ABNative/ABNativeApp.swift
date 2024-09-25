//

import Combine
import Foundation

public class ABNativeApp
{
    
    private let queue: DispatchQueue
    private let lock: NSLock
    
    private var initialized: Bool
    
    private var actionsSets: [String : ABNativeActionsSet]
    private var onWebResultCallbacks: [Int: ([String: AnyObject]?) -> Void]
    
    private var web_ActionId_Next: Int
    
    private var webView_Init_WebCalls: [ABNativeWebCall]
    private var webView_Initialized: Bool
    
    
    public var evaluateJS = PassthroughSubject<String, Never>()
    
    
    public init() {
        self.queue = DispatchQueue(label: "ABNativeApp.queue", attributes: .concurrent)
        self.lock = NSLock()
        
        self.initialized = false
        
        self.actionsSets = [String: ABNativeActionsSet]()
        self.onWebResultCallbacks = [Int: ([String: AnyObject]?) -> Void]()
        
        self.web_ActionId_Next = 0
        
        self.webView_Init_WebCalls = [ABNativeWebCall]()
        self.webView_Initialized = false
    }
    
    public func addActionsSet(_ actionsSetName: String, _ actionsSet: ABNativeActionsSet) {
        lock.lock()
        if initialized {
            fatalError("Cannot add action set after initialization.")
        }
        lock.unlock()
        
        actionsSets[actionsSetName] = actionsSet
    }
    
    public func callNative(_ actionId: Int, _ actionsSetName: String, _ actionName: String, _ actionArgs: [String: AnyObject]?) {
        // Should be using gurds!
        
        guard let actionsSet = self.actionsSets[actionsSetName] else {
            self.errorNative("Native Actions Set '\(actionsSetName)' not implemented.")
            return
        }
        
        guard let actionPair = actionsSet.getNative(actionName) else {
            self.errorNative("Native Action '\(actionsSetName):\(actionName)' not implemented.")
            return
        }
        
        let result: [String: AnyObject]?
        if let action = actionPair.action {
            do {
                result = try action(actionArgs)
                onNativeResult(actionId, actionsSetName, actionName, result)
            } catch {
                print("Error when calling '\(actionsSetName):\(actionName)': " + error.localizedDescription)
                print(error)
                errorNative("Error when calling '\(actionsSetName):\(actionName)': " + error.localizedDescription)
            }
            
        } else if let callbackAction = actionPair.callbackAction {
            callbackAction(actionArgs) { result in
                self.onNativeResult(actionId, actionsSetName, actionName, result)
            } _: { error in
                print("Error when calling '\(actionsSetName):\(actionName)': " + error.localizedDescription)
                print(error)
                self.errorNative("Error when calling '\(actionsSetName):\(actionName)': " + error.localizedDescription)
            }
        }
    }
    
    public func callWeb(_ actionsSetName: String, _ actionName: String, _ actionArgs: [String: AnyObject]?, onWebResultCallback: @escaping (_ result: [String: AnyObject]?) -> Void) {
        lock.lock()
        queue.sync {
            if !webView_Initialized {
                webView_Init_WebCalls.append(ABNativeWebCall(actionsSetName: actionsSetName, actionName: actionName, actionArgs: actionArgs, onWebResultCallback: onWebResultCallback))
                lock.unlock()
                return
            }
        }
        lock.unlock()
        
        let actionId = web_ActionId_Next
        web_ActionId_Next += 1
        
        onWebResultCallbacks[actionId] = onWebResultCallback
        
        let actionArgs_String: String
        if let actionArgs {
            do {
                if let actionArgs_String_Parsed = try String(data: JSONSerialization.data(withJSONObject: actionArgs), encoding: .utf8) {
                    actionArgs_String = actionArgs_String_Parsed
                } else {
                    actionArgs_String = "null"
                }
            } catch {
                errorNative("Cannot convert action args to string -> \(error)")
                actionArgs_String = "null"
            }
        } else {
            actionArgs_String = "null"
        }
        
        evaluateJS.send("abNative.callWeb(\(actionId),'\(actionsSetName)','\(actionName)',\(actionArgs_String))")
    }
    
    public func errorNative(_ message: String) {
        print("ABNative Error -> \(message)")
        self.evaluateJS.send("abNative.errorNative(\"\(message)\")")
    }
    
    public func onWebResult(_ actionId: Int, _ result: [String: AnyObject]?) {
        if let onWebResultCallback = self.onWebResultCallbacks[actionId] {
            onWebResultCallback(result)
            self.onWebResultCallbacks.removeValue(forKey: actionId)
        }
    }
    
    public func webViewInitialized() {
        print("Web view initialized.")
        
        lock.lock()
        webView_Initialized = true
        lock.unlock()
        
        webView_Init_WebCalls.forEach{ wc in
            callWeb(wc.actionsSetName, wc.actionName, wc.actionArgs, onWebResultCallback: wc.onWebResultCallback)
        }
    }
    
    
    private func getResultJSONString(actionName: String, result: [String: AnyObject]?) -> String? {
        do {
            return try String(data: JSONSerialization.data(withJSONObject: result), encoding: .utf8)
        } catch {
            errorNative("Action '\(actionName)' Result Error: \(error)")
            return nil
        }
    }
    
    private func onNativeResult(_ actionId: Int, _ actionsSetName: String, _ actionName: String, _ result: [String: AnyObject]?) {
        if result == nil {
            self.evaluateJS.send("abNative.onNativeResult(\(actionId), null)")
        } else {
            let result_String = getResultJSONString(actionName: actionName, result: result)
            if let result_String {
                self.evaluateJS.send("abNative.onNativeResult(\(actionId), \(result_String))")
            }
        }
    }
    
}

public struct ABNativeWebCall {
    let actionsSetName: String
    let actionName: String
    let actionArgs: [String: AnyObject]?
    let onWebResultCallback: (_ result: [String: AnyObject]?) -> Void
}
