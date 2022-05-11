//
//  ABNativeActionsSet.swift
//  Alta Associations
//
//  Created by Jakub Zolcik on 20/03/2021.
//

import Foundation

open class ABNativeActionsSet {
    
    private var actions: [String : ABNativeAction] = [String : ABNativeAction]()
    
    
    public init() {
        
    }
    
    public func addNative(_ actionName: String, _ action: ABNativeAction) -> ABNativeActionsSet {
        if self.actions.index(forKey: actionName) != nil {
            assert(true, "Action '" + actionName + "' already exists.")
            return self
        }
        
        self.actions[actionName] = action
        
        return self
    }
    
    public func getNative(_ actionName: String) -> ABNativeAction?
    {
        return self.actions[actionName]
    }
    
}
