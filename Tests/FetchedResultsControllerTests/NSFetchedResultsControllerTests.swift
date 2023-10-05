import CoreData
import XCTest

extension String {
	func leftPad(_ character: Character, min: Int) -> String {
		guard count < min else { return self }
		return String(repeating: character, count: min - count) + self
	}
}

let objectCount = 10000

@objc protocol _PFBatchFaultingArray {
	func arrayFromObjectIDs() -> Any
	func indexOfManagedObjectForObjectID(_ objectID: Any) -> UInt64
	// -(id)managedObjectIDAtIndex:(unsigned long long)arg1 ;
}

final class NSFetchedResultsControllerTests: XCTestCase {
	private var persistentContainer: NSPersistentContainer!
	private var context: NSManagedObjectContext { persistentContainer.viewContext }
	private var delegate: Delegate!

	private var controller: NSFetchedResultsController<Post>!

	override func setUpWithError() throws {
		persistentContainer = .testValue(generateExistingData: true)
		delegate = .init()

		let fetchRequest = Post.fetchRequest()
		fetchRequest.fetchBatchSize = 100
		fetchRequest.predicate = NSPredicate(format: "body = %@", "INSIDE")
		fetchRequest.sortDescriptors = [
			NSSortDescriptor(keyPath: \Post.title, ascending: true),
		]

		controller = NSFetchedResultsController(
			fetchRequest: fetchRequest,
			managedObjectContext: context,
			sectionNameKeyPath: nil,
			cacheName: nil
		)
		controller.delegate = delegate
	}

	override func tearDownWithError() throws {
		persistentContainer = nil
		delegate = nil
	}

	// MARK: - Tests

	@MainActor
	func testFetchesObjectsPerformance() async throws {
		measure {
			try? controller.performFetch()
		}
	}

	@MainActor
	func testNewlyInsertedObjectPerformance() async throws {
		try controller.performFetch()

		measure {
			for batch in 0 ..< 100 {
				for row in 0 ..< 10 {
					self.context.buildPost(title: "_" + String(batch * row).leftPad("0", min: 6), body: "INSIDE")
					self.context.buildPost(title: "_" + String(batch * row).leftPad("0", min: 6), body: "OUTSIDE")
				}
				context.processPendingChanges()
			}
		}
	}

	// literally too slow to run
//	@MainActor
//	func testDeletedObjectPerformance() async throws {
//		try controller.performFetch()
//
//		// then
//		measure {
//			for _ in 0 ..< 100 {
//				for _ in 0 ..< 10 {
//					guard let object = controller.fetchedObjects?.randomElement() else { continue }
//					context.delete(object)
//				}
//				context.processPendingChanges()
//			}
//		}
//	}
}

private final class Delegate: NSObject, NSFetchedResultsControllerDelegate {
	func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {}
}
