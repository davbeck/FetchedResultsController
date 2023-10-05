import Combine
import CoreData
import Dependencies
import Foundation
import Observation

@available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
@Observable
public final class FetchedResultsManager<Object: NSManagedObject> {
	@ObservationIgnored
	@Dependency(\.mainRunLoop) private var mainRunLoop

	public let fetchRequest: NSFetchRequest<Object>
	public let managedObjectContext: NSManagedObjectContext

	public private(set) var fetchedObjects: [Object]?

	private let notificationCenter = NotificationCenter.default

	public init(
		fetchRequest: NSFetchRequest<Object>,
		managedObjectContext: NSManagedObjectContext
	) {
		self.fetchRequest = fetchRequest
		self.managedObjectContext = managedObjectContext

		notificationCenter.addObserver(
			self,
			selector: #selector(managedObjectContextObjectsDidChange),
			name: .NSManagedObjectContextObjectsDidChange,
			object: managedObjectContext
		)

		setNeedsPerformFetch()
	}

	deinit {
		notificationCenter.removeObserver(self)
	}

	private var predicateRelationships: [[NSRelationshipDescription]] = []

	private var needsFetch = false
	public func setNeedsPerformFetch() {
		guard !needsFetch else { return }
		needsFetch = true

		mainRunLoop.schedule { [weak self] in
			guard let self, self.needsFetch else { return }
			do {
				try self.performFetch()
			} catch {
				print("failed to perform fetch", error)
			}
		}
	}

	public func performFetch() throws {
		needsFetch = false

		let objects = try managedObjectContext.fetch(fetchRequest)

		fetchedObjects = objects

		predicateRelationships = fetchRequest.predicate?
			.relationshipPath(from: Object.entity())
			.filter { !$0.isEmpty } ?? []
	}

	public func performFetchIfNeeded() throws {
		guard needsFetch else { return }
		try performFetch()
	}

	public var objectIDs: [NSManagedObjectID] {
		guard let fetchedObjects else { return [] }
		// this avoids fetching more data when using batched fetch requests
		return (fetchedObjects as NSArray).value(forKey: "objectID") as? [NSManagedObjectID] ?? []
	}

	// MARK: - Notifications

	private func lookup(_ element: Object) -> Int {
		guard let fetchedObjects else { return 0 }

		var lowerBound = fetchedObjects.startIndex
		var upperBound = fetchedObjects.endIndex
		while lowerBound < upperBound {
			let midIndex = lowerBound + (upperBound - lowerBound) / 2
			let result = (fetchRequest.sortDescriptors ?? []).compare(fetchedObjects[midIndex], to: element)
			switch result {
			case .orderedSame:
				return midIndex
			case .orderedAscending:
				lowerBound = midIndex + 1
			case .orderedDescending:
				upperBound = midIndex
			}
		}
		return lowerBound
	}

	@objc private func managedObjectContextObjectsDidChange(_ notification: Notification) {
//		print("managedObjectContextObjectsDidChange", notification)

		var objectIDs = Set(self.objectIDs)

		let updated = notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject> ?? []
		let refreshed = notification.userInfo?[NSRefreshedObjectsKey] as? Set<NSManagedObject> ?? []
		let inserted = notification.userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject> ?? []
		let deleted = notification.userInfo?[NSDeletedObjectsKey] as? Set<NSManagedObject> ?? []
		// let invalidatedAll = notification.userInfo?[NSInvalidatedAllObjectsKey] as? [NSManagedObjectID] ?? []
		// let invalidated = notification.userInfo?[NSInvalidatedObjectsKey] as? Set<NSManagedObject> ?? []

		func insert(_ object: Object) {
			let index = self.lookup(object)
			fetchedObjects?.insert(object, at: index)
			objectIDs.insert(object.objectID)
		}

		func remove(_ object: Object) {
			guard
				let index = self.objectIDs.firstIndex(of: object.objectID)
			else { return }
			fetchedObjects?.remove(at: index)
		}

		if updated.count + refreshed.count + inserted.count + deleted.count > 1000 {
			try? self.performFetch()
			return
		}

		var needsSort = false

		for object in deleted {
			guard let object = object as? Object else { continue }
			remove(object)
		}

		for object in inserted {
			guard let object = object as? Object else { continue }
			// if we perform fetch between when this object is created and when the changes are processed, we will get a duplicate
			if !objectIDs.contains(object.objectID), fetchRequest.predicate?.evaluate(with: object) != false {
				insert(object)
			}
		}

		var allUpdated = updated.union(refreshed)

		for predicateRelationship in predicateRelationships {
			let reversed = predicateRelationship.reversed().map(\.inverseRelationship)
			for object in allUpdated {
				for index in reversed.indices {
					guard
						let relationship = reversed[index],
						relationship.entity == object.entity
					else { continue }

					let objects = object.managedObjects(for: reversed[index...])
						.subtracting(inserted)
						.subtracting(deleted)

					allUpdated.formUnion(objects)
				}
			}
		}

		for object in allUpdated {
			if let object = object as? Object {
				let inFetchedObjects = objectIDs.contains(object.objectID)
				let inPredicate = fetchRequest.predicate?.evaluate(with: object) != false
				switch (inFetchedObjects, inPredicate) {
				case (true, false):
					remove(object)
				case (true, true):
					needsSort = true
				case (false, true):
					insert(object)
				case (false, false):
					break
				}
			}
		}

		if needsSort {
			fetchedObjects = (fetchedObjects as? NSArray)?
				.sortedArray(using: fetchRequest.sortDescriptors ?? []) as? [Object]
		}
	}
}
