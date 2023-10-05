import CoreData
import Dependencies
import FetchedResultsController
import XCTest

@MainActor
final class FetchedResultsControllerTests: XCTestCase {
	var persistentContainer: NSPersistentContainer!
	var context: NSManagedObjectContext { persistentContainer.viewContext }

	private var controller: FetchedResultsController<Post>!

	override func invokeTest() {
		withDependencies {
			$0.mainRunLoop = .immediate
		} operation: {
			super.invokeTest()
		}
	}

	override func setUp() async throws {
		persistentContainer = .testValue()

		let fetchRequest = Post.fetchRequest()
		fetchRequest.sortDescriptors = [
			NSSortDescriptor(keyPath: \Post.title, ascending: true),
		]

		controller = FetchedResultsController(
			fetchRequest: fetchRequest,
			managedObjectContext: context
		)
	}

	override func tearDown() async throws {
		persistentContainer = nil

		controller = nil
	}

	// MARK: - Tests

	func testFetchesObjects() throws {
		// given
		try autoreleasepool {
			context.buildPost(title: "a")
			context.buildPost(title: "b")
			context.buildPost(title: "c")
			try context.save()
		}

		// when
		try controller.performFetch()

		// then
		XCTAssertEqual(controller.fetchedObjects?.map(\.title), ["a", "b", "c"])
	}

	func testFetchesObjectsWithPredicate() throws {
		// given
		try autoreleasepool {
			context.buildPost(title: "a", body: "INSIDE")
			context.buildPost(title: "b", body: "OUTSIDE")
			context.buildPost(title: "c", body: "INSIDE")
			try context.save()
		}

		controller.fetchRequest.predicate = NSPredicate(format: "body = %@", "INSIDE")

		// when
		try controller.performFetch()

		// then
		XCTAssertEqual(controller.fetchedObjects?.map(\.title), ["a", "c"])
	}

	func testNewlyInsertedObject() throws {
		// given
		try autoreleasepool {
			context.buildPost(title: "a")
			context.buildPost(title: "c")
			try context.save()
		}

		try controller.performFetch()

		// when
		context.buildPost(title: "b")
		context.processPendingChanges()

		// then
		XCTAssertEqual(controller.fetchedObjects?.map(\.title), ["a", "b", "c"])
	}

	func testNewlyInsertedObjectOutsideOfPredicate() throws {
		// given
		try autoreleasepool {
			context.buildPost(title: "a", body: "INSIDE")
			context.buildPost(title: "c", body: "INSIDE")
			try context.save()
		}

		controller.fetchRequest.predicate = NSPredicate(format: "body = %@", "INSIDE")

		try controller.performFetch()

		// when
		context.buildPost(title: "b", body: "OUTSIDE")
		context.processPendingChanges()

		// then
		XCTAssertEqual(controller.fetchedObjects?.map(\.title), ["a", "c"])
	}

	func testDeletedObject() throws {
		// given
		let postB = context.buildPost(title: "b")
		try autoreleasepool {
			context.buildPost(title: "a")
			context.buildPost(title: "c")
			try context.save()
		}

		try controller.performFetch()

		// when
		context.delete(postB)
		context.processPendingChanges()

		// then
		XCTAssertEqual(controller.fetchedObjects?.map(\.title), ["a", "c"])
	}

	func testUpdatedObjectPosition() throws {
		// given
		let postB = context.buildPost(title: "b")
		try autoreleasepool {
			context.buildPost(title: "a")
			context.buildPost(title: "c")
			try context.save()
		}

		try controller.performFetch()

		// when
		postB.title = "d"
		context.processPendingChanges()

		// then
		XCTAssertEqual(controller.fetchedObjects?.map(\.body), ["A", "C", "B"])
	}

	func testUpdatedObjectJoinsPredicate() throws {
		// given
		let postB = context.buildPost(title: "b", body: "OUTSIDE")
		try autoreleasepool {
			context.buildPost(title: "a", body: "INSIDE")
			context.buildPost(title: "c", body: "INSIDE")
			try context.save()
		}

		controller.fetchRequest.predicate = NSPredicate(format: "body = %@", "INSIDE")

		try controller.performFetch()

		// when
		postB.body = "INSIDE"
		context.processPendingChanges()

		// then
		XCTAssertEqual(controller.fetchedObjects?.map(\.title), ["a", "b", "c"])
	}

	func testUpdatedObjectLeavesPredicate() throws {
		// given
		let postB = context.buildPost(title: "b", body: "INSIDE")
		try autoreleasepool {
			context.buildPost(title: "a", body: "INSIDE")
			context.buildPost(title: "c", body: "INSIDE")
			try context.save()
		}

		controller.fetchRequest.predicate = NSPredicate(format: "body = %@", "INSIDE")

		try controller.performFetch()

		// when
		postB.body = "OUTSIDE"
		context.processPendingChanges()

		// then
		XCTAssertEqual(controller.fetchedObjects?.map(\.title), ["a", "c"])
	}

	// MARK: - Background

	@MainActor
	func testNewlyInsertedObjectOnBackground() async throws {
		// given
		try autoreleasepool {
			context.buildPost(title: "a")
			context.buildPost(title: "c")
			try context.save()
		}

		try controller.performFetch()

		// when
		try await persistentContainer.performBackgroundTaskContinuation { context in
			context.buildPost(title: "b")
			try context.save()
		}

		// then
		XCTAssertEqual(controller.fetchedObjects?.map(\.title), ["a", "b", "c"])
	}

	@MainActor
	func testDeletedObjectOnBackground() async throws {
		// given
		let postB = context.buildPost(title: "b")
		try autoreleasepool {
			context.buildPost(title: "a")
			context.buildPost(title: "c")
			try context.save()
		}

		try controller.performFetch()

		// when
		let postBID = postB.objectID
		try await persistentContainer.performBackgroundTaskContinuation { context in
			let postB = context.object(with: postBID)
			context.delete(postB)
			try context.save()
		}

		// then
		XCTAssertEqual(controller.fetchedObjects?.map(\.title), ["a", "c"])
	}

	@MainActor
	func testUpdatedObjectPositionOnBackground() async throws {
		// given
		let postB = context.buildPost(title: "b")
		try autoreleasepool {
			context.buildPost(title: "a")
			context.buildPost(title: "c")
			try context.save()
		}

		try controller.performFetch()

		// when
		let postBID = postB.objectID
		try await persistentContainer.performBackgroundTaskContinuation { context in
			let postB = try XCTUnwrap(context.object(with: postBID) as? Post)
			postB.title = "d"
			try context.save()
		}

		// then
		XCTAssertEqual(controller.fetchedObjects?.map(\.body), ["A", "C", "B"])
	}

	@MainActor
	func testUpdatedObjectJoinsPredicateOnBackground() async throws {
		// given
		let postB = context.buildPost(title: "b", body: "OUTSIDE")
		try autoreleasepool {
			context.buildPost(title: "a", body: "INSIDE")
			context.buildPost(title: "c", body: "INSIDE")
			try context.save()
		}

		try controller.performFetch()

		// when
		let postBID = postB.objectID
		try await persistentContainer.performBackgroundTaskContinuation { context in
			let postB = try XCTUnwrap(context.object(with: postBID) as? Post)
			postB.body = "INSIDE"
			try context.save()
		}

		// then
		XCTAssertEqual(controller.fetchedObjects?.map(\.title), ["a", "b", "c"])
	}

	@MainActor
	func testUpdatedObjectLeavesPredicateOnBackground() async throws {
		// given
		let postB = context.buildPost(title: "b", body: "INSIDE")
		try autoreleasepool {
			context.buildPost(title: "a", body: "INSIDE")
			context.buildPost(title: "c", body: "INSIDE")
			try context.save()
		}

		controller.fetchRequest.predicate = NSPredicate(format: "body = %@", "INSIDE")

		try controller.performFetch()

		// when
		let postBID = postB.objectID
		try await persistentContainer.performBackgroundTaskContinuation { context in
			let postB = try XCTUnwrap(context.object(with: postBID) as? Post)
			postB.body = "OUTSIDE"
			try context.save()
		}

		// then
		XCTAssertEqual(controller.fetchedObjects?.map(\.title), ["a", "c"])
	}

	// MARK: - Relationship bases predicates

	func testUpdatesWhenRelationshipChanges() throws {
		let author = context.buildProfile(isAdmin: true)

		try autoreleasepool {
			let author2 = context.buildProfile(isAdmin: true)
			context.buildPost(title: "a", author: author, body: "INSIDE")
			context.buildPost(title: "b", author: author2, body: "INSIDE")
			context.buildPost(title: "c", author: author, body: "INSIDE")
			try context.save()
		}

		controller.fetchRequest.predicate = NSPredicate(format: "author.isAdmin = TRUE")

		try controller.performFetch()

		// when
		author.isAdmin = false
		context.processPendingChanges()

		// then
		XCTAssertEqual(controller.fetchedObjects?.map(\.title), ["b"])
	}

	func testUpdatesWhenCompoundRelationshipChanges() throws {
		let author = context.buildProfile(isAdmin: false)
		let postB = context.buildPost(title: "b", author: nil, body: "INSIDE")
		_ = context.buildComment(post: postB, author: author)

		try autoreleasepool {
			let author2 = context.buildProfile(isAdmin: true)

			context.buildPost(title: "a", author: author2, body: "INSIDE")
			context.buildPost(title: "c", author: author2, body: "INSIDE")

			try context.save()
		}

		controller.fetchRequest.predicate = NSPredicate(format: "author.isAdmin = TRUE OR ANY comments.author.isAdmin = TRUE")

		try controller.performFetch()

		// when
		author.isAdmin = true
		context.processPendingChanges()

		// then
		XCTAssertEqual(controller.fetchedObjects?.map(\.title), ["a", "b", "c"])
	}

	func testUpdatesWhenInRelationshipChanges() throws {
		let author = context.buildProfile(isAdmin: false)
		let postB = context.buildPost(title: "b", author: author, body: "INSIDE")
		let comment = context.buildComment(post: postB)

		try context.save()

		controller.fetchRequest.predicate = NSPredicate(format: "%@ IN author.comments", comment)

		try controller.performFetch()

		// when
		comment.author = author
		context.processPendingChanges()

		// then
		XCTAssertEqual(controller.fetchedObjects?.map(\.title), ["b"])
	}

	func testUpdatesWithSubquery() throws {
		let author = context.buildProfile(isAdmin: false)
		let postB = context.buildPost(title: "b", body: "INSIDE")
		let comment = context.buildComment(post: postB)

		try context.save()

		controller.fetchRequest.predicate = NSPredicate(format: "SUBQUERY(comments, $comment, $comment.author == %@).@count > 0", author)

		try controller.performFetch()

		// when
		comment.author = author
		context.processPendingChanges()

		// then
		XCTAssertEqual(controller.fetchedObjects?.map(\.title), ["b"])
	}

	@MainActor
	func testUpdatesWhenRelationshipChangesOnBackground() async throws {
		let author = context.buildProfile(isAdmin: true)

		try autoreleasepool {
			let author2 = context.buildProfile(isAdmin: true)
			context.buildPost(title: "a", author: author, body: "INSIDE")
			context.buildPost(title: "b", author: author2, body: "INSIDE")
			context.buildPost(title: "c", author: author, body: "INSIDE")
			try context.save()
		}

		controller.fetchRequest.predicate = NSPredicate(format: "author.isAdmin = TRUE")

		try controller.performFetch()

		// when
		let authorID = author.objectID
		try await persistentContainer.performBackgroundTaskContinuation { context in
			let author = try XCTUnwrap(context.object(with: authorID) as? Profile)
			author.isAdmin = false
			try context.save()
		}

		// then
		XCTAssertEqual(controller.fetchedObjects?.map(\.title), ["b"])
	}
}

// 'performBackgroundTask' is only available in iOS 15.0 or newer
private extension NSPersistentContainer {
	func performBackgroundTaskContinuation<T>(_ block: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
		try await withCheckedThrowingContinuation { continuation in
			self.performBackgroundTask { context in
				do {
					let output = try block(context)
					continuation.resume(returning: output)
				} catch {
					continuation.resume(throwing: error)
				}
			}
		}
	}
}
