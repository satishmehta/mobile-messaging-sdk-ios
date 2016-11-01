//
//  MOMessageSendingTests.swift
//  MobileMessagingExample
//
//  Created by okoroleva on 21.07.16.
//

import XCTest
@testable import MobileMessaging

class MOMessageSendingTests: MMTestCase {

    func testSendMOMessageSuccessfully() {
		
		weak var expectation = expectationWithDescription("Sending finished")
		
		//Precondiotions
		mobileMessagingInstance.currentUser?.internalId = MMTestConstants.kTestCorrectInternalID
		
		let moMessage1 = MOMessage(messageId: "m1", destination: MMTestConstants.kTestCorrectApplicationCode, text: "message1", customPayload: ["customKey" : "customValue1"])
		let moMessage2 = MOMessage(messageId: "m2", destination: MMTestConstants.kTestCorrectApplicationCode, text: "message2", customPayload: ["customKey" : "customValue2"])

		MobileMessaging.sendMessages([moMessage1, moMessage2]) { (messages, error) in
			XCTAssertEqual(messages?.first?.messageId, "m1")
			XCTAssertEqual(messages?.first?.text, "message1")
			XCTAssertEqual(messages?.first?.destination, MMTestConstants.kTestCorrectApplicationCode)
			XCTAssertEqual(messages?.first?.customPayload as! [String: String], ["customKey" : "customValue1"])
			XCTAssertEqual(messages?.first?.sentStatus, MOMessageSentStatus.SentSuccessfully)
			
			XCTAssertEqual(messages?.last?.messageId, "m2")
			XCTAssertEqual(messages?.last?.text, "message2")
			XCTAssertEqual(messages?.last?.destination, MMTestConstants.kTestCorrectApplicationCode)
			XCTAssertEqual(messages?.last?.customPayload as! [String: String], ["customKey" : "customValue2"])
			XCTAssertEqual(messages?.last?.sentStatus, MOMessageSentStatus.SentWithFailure)
			
			expectation?.fulfill()
		}
		
		waitForExpectationsWithTimeout(60, handler: nil)
    }

	func testMOMessageConstructors() {
		let mo1 = MOMessage(destination: "destination", text: "text", customPayload: ["meal": "pizza"])
		let dict1 = mo1.dictRepresentation
		
		let mo2 = MOMessage(payload: dict1)
		XCTAssertNotNil(mo2)
		let dict2 = mo2?.dictRepresentation
		
		let d1 = dict1 as NSDictionary
		let d2 = dict2! as NSDictionary
		XCTAssertTrue(d1.isEqual(d2))
		
	}
}
