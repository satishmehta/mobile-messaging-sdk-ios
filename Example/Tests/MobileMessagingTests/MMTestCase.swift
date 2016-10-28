//
//  MMTestCase.swift
//  MobileMessaging
//
//  Created by Andrey K. on 16/04/16.
//

import XCTest
import Foundation
import CoreData
@testable import MobileMessaging

//let queue = MMQueue.Serial.newQueue(queueName: "com.infobip.tests")

class MMTestCase: XCTestCase {
	var mobileMessagingInstance: MobileMessaging {
		var result: MobileMessaging? = nil
//		queue.executeSync { result = MobileMessaging.sharedInstance }
		result = MobileMessaging.sharedInstance
		return result!
	}
	
	var storage: MMCoreDataStorage {
		var result: MMCoreDataStorage? = nil
//		queue.executeSync { result = self.mobileMessagingInstance.internalStorage }
		result = self.mobileMessagingInstance.internalStorage
		return result!
	}
	
	override func setUp() {
//		queue.executeSync {
			super.setUp()
			MobileMessaging.logger.logOutput = .None
			MobileMessaging.logger.logLevel = .Off
			MobileMessaging.stop(true)
			startWithCorrectApplicationCode()
//		}
	}
	
	func cleanUpAndStop() {
//		queue.executeSync {
			MobileMessaging.stop(true)
//		}
	}
	
	override func tearDown() {
		super.tearDown()
		self.cleanUpAndStop()
	}
	
	func nonReportedStoredMessagesCount(_ ctx: NSManagedObjectContext) -> Int {
		var count: Int = 0
		ctx.reset()
		ctx.performAndWait {
			count = MessageManagedObject.MM_countOfEntitiesWithPredicate(NSPredicate(format: "reportSent == false"), inContext: ctx)
		}
		return count
	}
	
	func allStoredMessagesCount(_ ctx: NSManagedObjectContext) -> Int {
		var count: Int = 0
		ctx.reset()
		ctx.performAndWait {
			count = MessageManagedObject.MM_countOfEntitiesWithContext(ctx)
		}
		return count
	}
	
	func startWithApplicationCode(_ code: String) {
//		queue.executeSync {
			MobileMessaging.withApplicationCode(code, notificationType: []).withBackendBaseURL(MMTestConstants.kTestBaseURLString).start()
//		}
	}
	
	func startWithCorrectApplicationCode() {
//		queue.executeSync {
			MobileMessaging.withApplicationCode(MMTestConstants.kTestCorrectApplicationCode, notificationType: []).withBackendBaseURL(MMTestConstants.kTestBaseURLString).start()
//		}
	}
	
	func startWithWrongApplicationCode() {
//		queue.executeSync {
			MobileMessaging.withApplicationCode(MMTestConstants.kTestWrongApplicationCode, notificationType: []).withBackendBaseURL(MMTestConstants.kTestBaseURLString).start()
//		}
	}
}
