//
//  MMRetryableOperation.swift
//  MobileMessaging
//

import Foundation

class MMRetryableOperation: Operation {

	private var _retryCounter = -1
	private let counterLock = NSLock()
	private(set) var retryCounter: Int {
		set {
			counterLock.withCriticalScope {
				self._retryCounter = newValue
			}
		}
		get {
			return counterLock.withCriticalScope {
				 self._retryCounter
			}
		}
	}
	
	typealias MMRetryableOperationCompletion = (MMRetryableOperation) -> Void
	private(set) var retryLimit = 0
	private(set) var currentError: NSError?
	
	private var attemptObservers = [MMBlockObserver]()
	var finishCompletion: MMRetryableOperationCompletion
	
	// Override me!
	override func copy() -> Any {
		let acopy = type(of: self).init(retryLimit: self.retryLimit, completion: self.finishCompletion)
		acopy.retryCounter = self.retryCounter
		return acopy
	}
	
	// Override me
	func isErrorRetryable(_ error: NSError) -> Bool {
		return false
	}
	
	required init(retryLimit: Int, completion: @escaping MMRetryableOperationCompletion) {
		self.retryLimit = retryLimit
		self.finishCompletion = completion
	}
	
	class func delay(forAttempt attempt: Int) -> Int {
		return Int(pow(Double(attempt), 2))
	}
	
	class func makeSuccessor(withPredecessor predecessorOperation: MMRetryableOperation) -> MMRetryableOperation? {
		if let nextOp = predecessorOperation.copy() as? MMRetryableOperation, nextOp.shouldRetry(afterError: predecessorOperation.currentError){
			return nextOp
		} else {
			return nil
		}
	}
	
	private func shouldRetry(afterError error: NSError?) -> Bool {
		var isErrorOkToRetry = false
		switch error {
		case .some(let err) where isErrorRetryable(err):
			isErrorOkToRetry = true
		case .none:
			isErrorOkToRetry = false
		default:
			isErrorOkToRetry = false
		}

		return retryCounter < retryLimit && !isCancelled && isErrorOkToRetry
	}
	
	func addObserver(observer: MMBlockObserver) {
		attemptObservers.append(observer)
	}
	
	override func execute() {
		retryCounter += 1
		for obs in attemptObservers {
			obs.attemptDidStart(operation: self)
		}
	}
	
	override func finished(_ errors: [NSError]) {
		currentError = errors.first
		if !shouldRetry(afterError: currentError) {
			finishCompletion(self)
		}
		for obs in attemptObservers {
			obs.attemptDidFinish(operation: self, error: currentError)
		}
		attemptObservers.removeAll()
	}
}
