import CoreData
import Foundation

extension NSEntityDescription {
	func relationshipPath(forKeyPath keyPath: some Collection<String>) -> [NSRelationshipDescription] {
		guard
			let key = keyPath.first,
			let relationship = relationshipsByName[key]
		else { return [] }

		return [relationship] + (relationship.destinationEntity?.relationshipPath(forKeyPath: keyPath.dropFirst()) ?? [])
	}
}
