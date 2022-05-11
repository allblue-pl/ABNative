//
//  ABNativeApp.swift
//  Alta Associations
//
//  Created by Jakub Zolcik on 20/03/2021.
//

import Combine
import Foundation

public class ABNativeApp
{
    
    private var actionsSets: [String : ABNativeActionsSet] = [String : ABNativeActionsSet]()
    private var onWebResultInfos: [Int: ABNativeOnWebResultCallback] = [:]
    private var web_ActionId_Last: Int = 0
    
    
    public var evaluateJS = PassthroughSubject<String, Never>()
    
    
    public init() {
        
    }
    
    public func addActionsSet(_ actionsSetName: String, _ actionsSet: ABNativeActionsSet) {
        self.actionsSets[actionsSetName] = actionsSet
    }
    
    public func callNative(_ actionId: Int, _ actionsSetName: String, _ actionName: String, _ actionArgs: [String: AnyObject]) {
        // Should be using gurds!
        
        let actionsSet = self.actionsSets[actionsSetName]
        if actionsSet == nil {
            self.errorNative("Native Actions Set '\(actionsSetName)' not implemented.")
            return
        }
        
        let action = actionsSet?.getNative(actionName)
        if (action == nil) {
            self.errorNative("Native Action '\(actionsSetName):\(actionName)' not implemented.")
            return
        }
        
        var actionResult = ABNativeAction.Result({ (result: [String: AnyObject?]) in
            let json_String: String?
            do {
                json_String = try String(data: JSONSerialization.data(withJSONObject: result), encoding: .utf8)
            } catch {
                self.errorNative("Action '\(actionName)' Result Error: \(error)")
                return
            }
            
            self.evaluateJS.send("abNative.onNativeResult(" + String(actionId) + "," + (json_String ?? "{}") + ")")
        })
        
        action?.call(actionArgs, actionResult)
    }
    
    public func callWeb(_ actionsSetName: String, _ actionName: String, _ actionArgs: [String: AnyObject], onWebResult: ABNativeOnWebResultCallback? = nil) {
        self.web_ActionId_Last += 1
        let actionId = self.web_ActionId_Last
        self.onWebResultInfos[actionId] = onWebResult
        
        let actionArgs_String: String?
        do {
            actionArgs_String = try String(data: JSONSerialization.data(withJSONObject: actionArgs), encoding: .utf8)
        } catch {
            self.errorNative("Action '\(actionName)' Args Error: \(error)")
            return
        }
        
        self.evaluateJS.send("abNative.callWeb(\(actionId),'\(actionsSetName)','\(actionName)',\(actionArgs_String ?? "{}"))")
    }
    
    public func errorNative(_ message: String) {
        print("ABNative Error -> \(message)")
        self.evaluateJS.send("abNative.errorNative(\"\(message)\")")
    }
    
    public func onWebResult(_ actionId: Int, _ result: [String: AnyObject]) {
    let onWebResultCallback = self.onWebResultInfos[actionId]
        onWebResultCallback?.call(result)
        self.onWebResultInfos.removeValue(forKey: actionId)
    }
    
}
