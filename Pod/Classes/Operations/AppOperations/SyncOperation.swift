//
//  SyncOperation.swift
//
//  Created by Andrey K. on 20/06/16.
//

import Foundation
import CoreData

final class SyncOperation: Operation {
	var context: NSManagedObjectContext
	var finishBlock: (MMFetchMessagesResult -> Void)?
	var remoteAPIQueue: MMRemoteAPIQueue
	var result = MMFetchMessagesResult.Cancel
	
	init(context: NSManagedObjectContext, remoteAPIQueue: MMRemoteAPIQueue, finishBlock: (MMFetchMessagesResult -> Void)? = nil) {
		self.context = context
		self.remoteAPIQueue = remoteAPIQueue
		self.finishBlock = finishBlock
		
		super.init()
		
		self.addCondition(RegistrationCondition())
	}
	
	override func execute() {
		self.syncMessages()
	}
	
	private func syncMessages() {
		self.context.performBlockAndWait {
			guard let internalId = MobileMessaging.currentInstallation?.internalId else {
				self.finishWithError(NSError(type: MMInternalErrorType.NoRegistration))
				return
			}
			
			let date = NSDate(timeIntervalSinceNow: -60 * 60 * 24 * 7) // 7 days ago
			
			let nonReportedMessages = MessageManagedObject.MM_findAllWithPredicate(NSPredicate(format: "reportSent == false"), inContext: self.context) as? [MessageManagedObject]
			let archivedMessages = MessageManagedObject.MM_findAllWithPredicate(NSPredicate(format: "reportSent == true && creationDate > %@", date), inContext: self.context) as? [MessageManagedObject]
			
			let nonReportedMessageIds = nonReportedMessages?.map{ $0.messageId }
			let archveMessageIds = archivedMessages?.map{ $0.messageId }
			
			let request = MMGetSyncRequest(internalId: internalId, archiveMsgIds: archveMessageIds, dlrMsgIds: nonReportedMessageIds)
			
			self.remoteAPIQueue.performRequest(request) { result in
				self.handleRequestResponse(result, nonReportedMessageIds: nonReportedMessageIds)
			}
		}
	}

	private func handleRequestResponse(result: MMFetchMessagesResult, nonReportedMessageIds: [String]?) {
		self.result = result
		
		self.context.performBlockAndWait {
			switch result {
			case .Success(let fetchResponse):
				let fetchedMessages = fetchResponse.messages
				MMLogInfo("Messages fetching succeded: received \(fetchedMessages?.count) new messages: \(fetchedMessages)")
				
				if let nonReportedMessageIds = nonReportedMessageIds {
					self.dequeueDeliveryReports(nonReportedMessageIds)
					MMLogInfo("Delivery report sent for messages: \(nonReportedMessageIds)")
					if nonReportedMessageIds.count > 0 {
						NSNotificationCenter.mm_postNotificationFromMainThread(MMNotificationDeliveryReportSent, userInfo: [MMNotificationKeyDLRMessageIDs: nonReportedMessageIds])
					}
				}
				
			case .Failure(let error):
				MMLogError("Sync request failed with error: \(error)")
			case .Cancel:
				MMLogInfo("Sync cancelled")
				break
			}
			self.finishWithError(result.error)
		}
	}
	
	private func dequeueDeliveryReports(messageIDs: [String]) {
		guard let messages = MessageManagedObject.MM_findAllWithPredicate(NSPredicate(format: "messageId IN %@", messageIDs), inContext: context) as? [MessageManagedObject]
			where messages.count > 0
			else
		{
			return
		}
		
		for message in messages {
			message.reportSent = true
		}
		
		MMLogDebug("Marked as delivered: \(messages.map{ $0.messageId })")
		context.MM_saveToPersistentStoreAndWait()
	}
	
	private func handleMessageOperation(messages: [MMMessage]) -> MessageHandlingOperation {
		return MessageHandlingOperation(userInfos: messages.flatMap { $0.payload },
		                                messagesOrigin: .Server,
		                                context: self.context,
		                                remoteAPIQueue: self.remoteAPIQueue,
		                                newMessageReceivedCallback: nil) { error in
											
											var finalResult = self.result
											if let error = error {
												finalResult = MMFetchMessagesResult.Failure(error)
											}
											self.finishBlock?(finalResult)
		}
	}
	
	override func finished(errors: [NSError]) {
		switch result {
		case .Success(let fetchResponse):
			if let messages = fetchResponse.messages where messages.count > 0 {
				self.produceOperation(handleMessageOperation(messages))
			} else {
				self.finishBlock?(result)
			}
		default:
			self.finishBlock?(result)
		}
	}
}