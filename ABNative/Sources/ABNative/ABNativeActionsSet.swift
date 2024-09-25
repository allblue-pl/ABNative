
import Foundation

open class ABNativeActionsSet {
    
    private var actions: [String: ABNativeActionPair]
    
    
    public init() {
        self.actions = [String: ABNativeActionPair]()
    }
    
    public func addNative(_ actionName: String, execute action: @escaping (_ args: [String: AnyObject]?) -> [String: AnyObject]?) -> ABNativeActionsSet {
        if actions.index(forKey: actionName) != nil {
            assertionFailure("Action '" + actionName + "' already exists.")
            return self
        }
        
        ABNativeActionPair(action: action, callbackAction: nil)
        
        actions[actionName] = nil
        
        return self
    }
    
    public func addNativeCallback(_ actionName: String, execute callbackAction: @escaping (_ args: [String: AnyObject]?, _ onResult: @escaping (_ result: [String: AnyObject]?) -> Void, _ onError: @escaping (_ error: Error) -> Void) -> Void) -> ABNativeActionsSet {
        if actions.index(forKey: actionName) != nil {
            assertionFailure("Action '" + actionName + "' already exists.")
            return self
        }
        
        actions[actionName] = ABNativeActionPair(action: nil, callbackAction: callbackAction)
        
        return self
    }
    
    public func getNative(_ actionName: String) -> ABNativeActionPair?
    {
        if let action = actions[actionName] {
            return action
        }
        
        assertionFailure("Action '\(actionName)' does not exist.")
        return nil
    }
    
}


public struct ABNativeActionPair {
    let action: ((_ args: [String: AnyObject]?) -> [String: AnyObject]?)?
    let callbackAction: ((_ args: [String: AnyObject]?, _ onResult: @escaping (_ result: [String: AnyObject]?) -> Void, _ onError: @escaping (_ error: Error) -> Void) -> Void)?
}
