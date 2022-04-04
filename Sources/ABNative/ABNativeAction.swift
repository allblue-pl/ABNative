//
//  ABNativeAction.swift
//  Alta Associations
//
//  Created by Jakub Zolcik on 20/03/2021.
//

import Foundation

public class ABNativeAction {
    static public func jsonArgsError() -> [String: AnyObject] {
        var result = [String: AnyObject]()
        result["_ABNativeJSONArgsError"] = "Cannot parse args from json." as AnyObject
        return result
    }
    
    private let callFn: (([String: AnyObject]) -> [String: AnyObject])?
    private let callFn_Async: (([String: AnyObject], Result) -> Void)?
    
    init(callFn: @escaping ([String: AnyObject]) -> [String: AnyObject]) {
        self.callFn = callFn
        self.callFn_Async = nil
    }
    
    init(callAsyncFn: @escaping ([String: AnyObject], Result) -> Void) {
        self.callFn = nil
        self.callFn_Async = callAsyncFn
    }
    
    public func call(_ actionArgs: [String: AnyObject], _ actionResult: Result) -> Void {
        if (self.callFn != nil) {
            let result = self.callFn!(actionArgs)
            actionResult.resolve(result)
        } else if (self.callFn_Async != nil) {
            self.callFn_Async!(actionArgs, actionResult)
        } else {
            assert(true, "Unknown callFn type.")
        }
    }
    
    
    public class Result {
        private var onResultFn: ([String: AnyObject]) -> Void
        
        init(_ onResult: @escaping ([String: AnyObject]) -> Void) {
            self.onResultFn = onResult
        }
        
        public func error(_ message: String) {
            
        }
        
        public func resolve(_ result: [String: AnyObject]) {
            self.onResultFn(result)
        }
    }
    
}

public enum ABNativeActionError: Error {
    case cannotParseJSON
}

