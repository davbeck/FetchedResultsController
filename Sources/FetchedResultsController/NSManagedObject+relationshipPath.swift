import CoreData
import Foundation

extension NSManagedObject {
	func managedObjects(for relationship: NSRelationshipDescription) -> Set<NSManagedObject> {
		let value = self.value(forKey: relationship.name)

		if let value = value as? NSOrderedSet {
			return value.set as? Set<NSManagedObject> ?? []
		} else if let value = value as? Set<NSManagedObject> {
			return value
		} else if let value = value as? NSManagedObject {
			return [value]
		}

		return []
	}

	func managedObjects(for relationships: some Collection<NSRelationshipDescription?>) -> Set<NSManagedObject> {
		guard let relationship = relationships.first, let relationship else { return [] }

		let objects = self.managedObjects(for: relationship)

		if relationships.count > 1 {
			return .init(objects.flatMap { $0.managedObjects(for: relationships.dropFirst()) })
		} else {
			return objects
		}
	}
}
