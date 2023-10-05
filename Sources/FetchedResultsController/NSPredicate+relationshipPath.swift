import CoreData
import Foundation

extension NSPredicate {
	@objc func relationshipPath(from entity: NSEntityDescription) -> [[NSRelationshipDescription]] {
		[]
	}
}

extension NSComparisonPredicate {
	override func relationshipPath(from entity: NSEntityDescription) -> [[NSRelationshipDescription]] {
		leftExpression.relationshipPath(from: entity) + rightExpression.relationshipPath(from: entity)
	}
}

extension NSCompoundPredicate {
	override func relationshipPath(from entity: NSEntityDescription) -> [[NSRelationshipDescription]] {
		subpredicates
			.compactMap { $0 as? NSPredicate }
			.flatMap { $0.relationshipPath(from: entity) }
	}
}
