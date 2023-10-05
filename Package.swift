// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
	name: "FetchedResultsController",
	platforms: [
		.iOS(.v13),
		.macOS(.v10_15),
	],
	products: [
		// Products define the executables and libraries a package produces, making them visible to other packages.
		.library(
			name: "FetchedResultsController",
			targets: ["FetchedResultsController"]
		),
	],
	dependencies: [
		.package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.0.0"),
	],
	targets: [
		// Targets are the basic building blocks of a package, defining a module or a test suite.
		// Targets can depend on other targets in this package and products from dependencies.
		.target(
			name: "FetchedResultsController",
			dependencies: [
				.product(name: "Dependencies", package: "swift-dependencies"),
			],
			swiftSettings: [
				.enableUpcomingFeature("ConciseMagicFile"),
				.enableUpcomingFeature("BareSlashRegexLiterals"),
				.enableUpcomingFeature("ExistentialAny"),
				.enableUpcomingFeature("ForwardTrailingClosures"),
				.enableUpcomingFeature("StrictConcurrency"),
			]
		),
		.testTarget(
			name: "FetchedResultsControllerTests",
			dependencies: ["FetchedResultsController"]
		),
	]
)
