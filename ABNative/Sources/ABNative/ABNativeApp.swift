//

import Combine
import Foundation

public class ABNativeApp
{
    
    private let errorCallback: ((_ error: String) -> Void)?
    
    private let queue: DispatchQueue
    private let lock: NSLock
    
    private var initialized: Bool
    
    private var actionsSets: [String : ABNativeActionsSet]
    private var webResultCallbacks: [Int: ABWebResultCallback]
    
    private var web_ActionId_Next: Int
    
    private var webView_Init_WebCalls: [ABNativeWebCall]
    private var webView_Initialized: Bool
    
    
    public var evaluateJS = PassthroughSubject<String, Never>()
    
    
    public init(execute errorCallback: ((_ error: String) -> Void)? = nil) {
        self.errorCallback = errorCallback
        
        self.queue = DispatchQueue(label: "ABNativeApp.queue", attributes: .concurrent)
        self.lock = NSLock()
        
        self.initialized = false
        
        self.actionsSets = [String: ABNativeActionsSet]()
        self.webResultCallbacks = [Int: ABWebResultCallback]()
        
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
        queue.sync {
            guard let actionsSet = self.actionsSets[actionsSetName] else {
                onNativeResult(actionId, actionsSetName, actionName, nil, "Native Actions Set '\(actionsSetName)' not implemented. Cannot call '\(actionsSetName):\(actionName)'.")
                return
            }
            
            guard let actionPair = actionsSet.getNative(actionName) else {
                onNativeResult(actionId, actionsSetName, actionName, nil, "Native Action '\(actionsSetName):\(actionName)' not implemented.")
                return
            }
            
            let result: [String: AnyObject]?
            if let action = actionPair.action {
                do {
                    result = try action(actionArgs)
                    onNativeResult(actionId, actionsSetName, actionName, result, nil)
                } catch {
                    errorMessage("Error when calling '\(actionsSetName):\(actionName)': " + error.localizedDescription)
                    print(error)
                    onNativeResult(actionId, actionsSetName, actionName, nil, "Error when calling '\(actionsSetName):\(actionName)': " + error.localizedDescription)
                }
                
            } else if let callbackAction = actionPair.callbackAction {
                callbackAction(actionArgs) { result in
                    self.onNativeResult(actionId, actionsSetName, actionName, result, nil)
                } _: { error in
                    self.errorMessage("Error when calling '\(actionsSetName):\(actionName)': " + error.localizedDescription)
                    print(error)
                    self.onNativeResult(actionId, actionsSetName, actionName, nil, "Error when calling '\(actionsSetName):\(actionName)': " + error.localizedDescription)
                }
            }
        }
    }
    
    public func callWeb(_ actionsSetName: String, _ actionName: String, _ actionArgs: [String: AnyObject]? = nil, execute onWebResult: @escaping (_ result: [String: AnyObject]?) -> Void, execute onWebError: @escaping (_ error: String) -> Void) {
        queue.sync {
            lock.lock()
            
            if !webView_Initialized {
                webView_Init_WebCalls.append(ABNativeWebCall(actionsSetName: actionsSetName, actionName: actionName, actionArgs: actionArgs, onWebResult: onWebResult, onWebError: onWebError))
                lock.unlock()
                return
            }
            
            lock.unlock()
            
            let actionId = web_ActionId_Next
            web_ActionId_Next += 1
            
            webResultCallbacks[actionId] = ABWebResultCallback(onWebResult: onWebResult, onWebError: onWebError)
            
            let actionArgs_String: String
            if let actionArgs {
                do {
                    if let actionArgs_String_Parsed = try String(data: JSONSerialization.data(withJSONObject: actionArgs), encoding: .utf8) {
                        actionArgs_String = actionArgs_String_Parsed
                    } else {
                        actionArgs_String = "null"
                    }
                } catch {
                    errorMessage("ABNativeApp Error -> Cannot convert action args to string -> \(error)")
                    actionArgs_String = "null"
                }
            } else {
                actionArgs_String = "null"
            }
            
            evaluateJS.send("abNative.callWeb(\(actionId),'\(actionsSetName)','\(actionName)',\(actionArgs_String))")
        }
    }
    
    public func errorMessage(_ error: String) {
        queue.sync {
            print("ABNativeApp Error ->", error)
            if let errorCallback {
                errorCallback(error)
            }
            self.evaluateJS.send("abNative.errorNative(\"\(error)\")")
        }
    }
    
    public func onWebResult(_ actionId: Int, _ result: [String: AnyObject]?, _ error: String?) {
        queue.sync {
            guard let webResultCallback = self.webResultCallbacks[actionId] else {
                errorMessage("ABNativeApp Error -> Cannot find action '\(actionId)' callback.")
                return
            }
            
            self.webResultCallbacks.removeValue(forKey: actionId)
            
            if let error {
                webResultCallback.onWebError(error)
            } else {
                webResultCallback.onWebResult(result)
            }
        }
    }
    
    public func webViewInitialized() {
        queue.sync {
            lock.lock()
            webView_Initialized = true
            lock.unlock()
            
            webView_Init_WebCalls.forEach{ wc in
                callWeb(wc.actionsSetName, wc.actionName, wc.actionArgs, execute: wc.onWebResult, execute: wc.onWebError)
            }
        }
    }
    
    
    private func getResultJSONString(actionName: String, result: [String: AnyObject]?) -> String? {
        do {
            return try String(data: JSONSerialization.data(withJSONObject: result), encoding: .utf8)
        } catch {
            errorMessage("ABNativeApp Error -> Cannot parse action '\(actionName)' result: \(error)")
            return nil
        }
    }
    
    private func onNativeResult(_ actionId: Int, _ actionsSetName: String, _ actionName: String, _ result: [String: AnyObject]?, _ error: String?) {
        guard error == nil else {
            let error_Str = error?.replacingOccurrences(of: "\"", with: "\\\"") ?? "Unknown Error"
            self.evaluateJS.send("abNative.onNativeResult(\(actionId), null, \"\(error_Str)\")")
            return
        }
        
        if result == nil {
            self.evaluateJS.send("abNative.onNativeResult(\(actionId), null, null)")
        } else {
            let result_String = getResultJSONString(actionName: actionName, result: result)
            if let result_String {
                self.evaluateJS.send("abNative.onNativeResult(\(actionId), \(result_String), null)")
            }
        }
    }
    
}

public struct ABNativeWebCall {
    let actionsSetName: String
    let actionName: String
    let actionArgs: [String: AnyObject]?
    let onWebResult: (_ result: [String: AnyObject]?) -> Void
    let onWebError: (_ error: String) -> Void
}

public struct ABWebResultCallback {
    let onWebResult: ([String: AnyObject]?) -> Void
    let onWebError: (String) -> Void
}
