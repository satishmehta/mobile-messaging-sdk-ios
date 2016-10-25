//
//  GeoEventReportingOperation.swift
//
//  Created by Andrey K. on 21/10/2016.
//
//

import UIKit
import CoreData

class GeoEventReportingOperation: Operation {
	var context: NSManagedObjectContext
	var finishBlock: (MMGeoEventReportingResult -> Void)?
	var remoteAPIQueue: MMRemoteAPIQueue
	var result = MMGeoEventReportingResult.Cancel
	var sentIds = [NSManagedObjectID]()
	
	
	init(context: NSManagedObjectContext, remoteAPIQueue: MMRemoteAPIQueue, finishBlock: (MMGeoEventReportingResult -> Void)? = nil) {
		self.context = context
		self.remoteAPIQueue = remoteAPIQueue
		self.finishBlock = finishBlock
	}
	
	override func execute() {
		self.context.performBlockAndWait {
			guard let happenedEvents = GeoEventReportObject.MM_findAllInContext(self.context) as? [GeoEventReportObject] where !happenedEvents.isEmpty
				else
			{
				MMLogDebug("[Geo event reporting] There is no non-reported geo events to send to the server. Finishing...")
				self.finish()
				return
			}
			
			let geoEventReportsDate = happenedEvents.flatMap { event -> GeoEventReportData? in
				guard let eventType = MMRegionEventType(rawValue: event.eventType) else {
					return nil
				}
				self.sentIds.append(event.objectID)
				return GeoEventReportData(geoAreaId: event.geoAreaId, eventType: eventType, campaignId: event.campaignId, eventDate: event.eventDate)
			}
			
			if let request = MMGeoEventsReportingRequest(eventsDataList: geoEventReportsDate) {
				self.remoteAPIQueue.perform(request: request) { result in
					self.handleRequestResult(result)
					self.finishWithError(result.error)
				}
			} else {
				MMLogDebug("[Geo event reporting] There is no non-reported geo events to send to the server. Finishing...")
				self.finish()
			}
		}
	}
	
	private func handleRequestResult(result: MMGeoEventReportingResult) {
		self.result = result
		switch result {
		case .Success(_):
			MMLogError("[Geo event reporting] Geo event reporting request succeeded.")
			context.performBlockAndWait {
				if let happenedEvents = GeoEventReportObject.MM_findAllWithPredicate(NSPredicate(format: "SELF IN %@", self.sentIds), inContext: self.context) as? [GeoEventReportObject] where !happenedEvents.isEmpty {
					happenedEvents.forEach({ event in
						self.context.deleteObject(event)
					})
					self.context.MM_saveToPersistentStoreAndWait()
				}
			}
		case .Failure(let error):
			MMLogError("[Geo event reporting] Geo event reporting request failed with error: \(error)")
		case .Cancel: break
		}
	}
	
	override func finished(errors: [NSError]) {
		if let error = errors.first {
			result = MMGeoEventReportingResult.Failure(error)
		}
		finishBlock?(result)
	}
}