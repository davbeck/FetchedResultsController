import CoreData
import Dependencies
import FetchedResultsController
import XCTest

final class FetchedResultsControllerPerformanceTests: XCTestCase {
	private var persistentContainer: NSPersistentContainer!
	private var context: NSManagedObjectContext { persistentContainer.viewContext }

	private var controller: FetchedResultsController<Post>!

	override func invokeTest() {
		withDependencies {
			$0.mainRunLoop = .immediate
		} operation: {
			super.invokeTest()
		}
	}

	override func setUpWithError() throws {
		persistentContainer = .testValue(generateExistingData: true)

		let fetchRequest = Post.fetchRequest()
		fetchRequest.fetchBatchSize = 100
		fetchRequest.predicate = NSPredicate(format: "body = %@", "INSIDE")
		fetchRequest.sortDescriptors = [
			NSSortDescriptor(keyPath: \Post.title, ascending: true),
		]

		controller = FetchedResultsController(
			fetchRequest: fetchRequest,
			managedObjectContext: context
		)
	}

	override func tearDownWithError() throws {
		persistentContainer = nil

		controller = nil
	}

	// MARK: - Tests

	@MainActor
	func testFetchesObjectsPerformance() async throws {
		// then
		measure {
			try? controller.performFetch()
		}
	}

	@MainActor
	func testNewlyInsertedObjectPerformance() async throws {
		try? controller.performFetch()

		// then
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

	@MainActor
	func testDeletedObjectPerformance() async throws {
		try? controller.performFetch()

		measure {
			for _ in 0 ..< 100 {
				for _ in 0 ..< 10 {
					guard let object = controller.fetchedObjects?.randomElement() else { continue }
					context.delete(object)
				}
				context.processPendingChanges()
			}
		}
	}
}
