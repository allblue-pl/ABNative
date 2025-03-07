
import Foundation

public class ABNativeAction {
    private let callFn: (([String: AnyObject]) -> [String: AnyObject])?
    private let callFn_Async: (([String: AnyObject], Result) -> Void)?
    
    public init(callFn: @escaping ([String: AnyObject]) -> [String: AnyObject]) {
        self.callFn = callFn
        self.callFn_Async = nil
    }
    
    public init(callAsyncFn: @escaping ([String: AnyObject], Result) -> Void) {
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
            assertionFailure("Unknown callFn type.")
        }
    }
    
    
    public class Result {
        private var onResultFn: ([String: AnyObject]) -> Void
        
        public init(_ onResult: @escaping ([String: AnyObject]) -> Void) {
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

