import Foundation

extension Collection where Element: NSSortDescriptor {
	func compare(_ object1: Any, to object2: Any) -> ComparisonResult {
		for descriptor in self {
			switch descriptor.compare(object1, to: object2) {
			case .orderedSame:
				continue
			case .orderedAscending:
				return .orderedAscending
			case .orderedDescending:
				return .orderedDescending
			}
		}

		return .orderedSame
	}
}
