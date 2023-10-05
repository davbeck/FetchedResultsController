import CoreData
import Foundation
import XCTest

private let modelBundle = Bundle.module

extension NSManagedObjectModel {
	convenience init(name: String, version: String) {
		let omoURL = modelBundle.url(forResource: version, withExtension: "omo", subdirectory: "\(name).momd")
		let momURL = modelBundle.url(forResource: version, withExtension: "mom", subdirectory: "\(name).momd")
		guard let url = omoURL ?? momURL else { fatalError("model version \(version) in \(name) not found") }
		self.init(contentsOf: url)!
	}

	static let exampleCurrent = NSManagedObjectModel(name: "Example", version: "Example")
}

extension NSPersistentContainer {
	private static func testValue(storeURL: URL) -> NSPersistentContainer {
		let container = NSPersistentContainer(name: "Example", managedObjectModel: .exampleCurrent)

		let storeDescription = NSPersistentStoreDescription(url: storeURL)
		storeDescription.setOption(NSNumber(true), forKey: NSPersistentHistoryTrackingKey)
		container.persistentStoreDescriptions = [storeDescription]

		container.loadPersistentStores { persistentStoreDescription, error in
			XCTAssertNil(error)
		}

		container.viewContext.automaticallyMergesChangesFromParent = true

		return container
	}

	static func testValue(generateExistingData: Bool = false) -> NSPersistentContainer {
		let storeURL = FileManager.default.temporaryDirectory
			.appendingPathComponent(UUID().uuidString)
			.appendingPathExtension("sqlite")

		if generateExistingData {
			autoreleasepool {
				let container = self.testValue(storeURL: storeURL)
				let context = container.viewContext

				for i in 0 ..< objectCount {
					context.buildPost(title: String(i).leftPad("0", min: 6), body: "INSIDE")
					context.buildPost(title: String(i).leftPad("0", min: 6), body: "OUTSIDE")
				}

				try! context.save()
			}
		}

		return self.testValue(storeURL: storeURL)
	}
}
