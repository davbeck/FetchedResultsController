import CoreData
import Foundation

extension NSExpression {
	@TaskLocal static var variableEntities: [String: NSEntityDescription] = [:]

	func relationshipPath(from entity: NSEntityDescription) -> [[NSRelationshipDescription]] {
		switch expressionType {
		case .constantValue:
			return []
		case .evaluatedObject:
			return []
		case .variable:
			return []
		case .keyPath:
			return [entity.relationshipPath(forKeyPath: keyPath.components(separatedBy: "."))]
		case .function:
			// operand.variable = "comment"
			// NSExpression.variableEntities
			// function = "valueForKeyPath:"
			if
				function == "valueForKeyPath:",
				let keyPathArgument = arguments?.first, keyPathArgument.expressionType.rawValue == 10,
				operand.expressionType == .variable,
				let variableEntity = NSExpression.variableEntities[operand.variable]
			{
				return [variableEntity.relationshipPath(forKeyPath: keyPathArgument.keyPath.components(separatedBy: "."))]
			}

			return (self.arguments?.flatMap { $0.relationshipPath(from: entity) } ?? []) + operand.relationshipPath(from: entity)
		case .unionSet:
			return []
		case .intersectSet:
			return []
		case .minusSet:
			return []
		case .subquery:
			guard
				let collection = self.collection as? NSExpression,
				collection.expressionType == .keyPath
			else { return [] }

			let relationshipPath = entity.relationshipPath(forKeyPath: collection.keyPath.components(separatedBy: "."))

			var variableEntities = NSExpression.variableEntities
			variableEntities[variable] = relationshipPath.last?.destinationEntity
			return NSExpression.$variableEntities.withValue(variableEntities) {
				predicate.relationshipPath(from: entity)
					.map { relationshipPath + $0 }
			}
		case .aggregate:
			// not supported by CoreData
			return []
		case .anyKey:
			print("anyKey")
		case .block:
			// not supported by CoreData
			return []
		case .conditional:
			print("conditional")
		@unknown default:
			// rawValue = 10 is fairly common for things like @count and other keyPaths
			return []
		}

		return []
	}
}
