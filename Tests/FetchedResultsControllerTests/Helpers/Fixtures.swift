import CoreData
import Foundation

extension NSManagedObjectContext {
	@discardableResult
	func buildPost(
		title: String,
		author: Profile? = nil,
		body: String? = nil
	) -> Post {
		let post = Post(context: self)
		post.title = title
		post.author = author
		post.body = body ?? title.uppercased()

		return post
	}

	@discardableResult
	func buildProfile(
		isAdmin: Bool
	) -> Profile {
		let profile = Profile(context: self)
		profile.isAdmin = isAdmin

		return profile
	}

	@discardableResult
	func buildComment(
		post: Post,
		author: Profile? = nil
	) -> Comment {
		let comment = Comment(context: self)
		comment.post = post
		comment.author = author

		return comment
	}
}
