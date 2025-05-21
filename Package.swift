// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CoreDataClient",
	platforms: [
		.iOS(.v15), .macOS(.v13), .tvOS(.v15), .watchOS(.v8)
	],
    products: [
		.singleTargetLibrary("CoreDataClient"),
		.singleTargetLibrary("CoreDataClientLive"),
    ],
	dependencies: [
		.package(url: "https://github.com/pointfreeco/swift-composable-architecture.git", branch: "main"),
	],
    targets: [
        .target(
            name: "CoreDataClient",
			dependencies: [
				.product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
			]
		),
		.target(
			name: "CoreDataClientLive",
			dependencies: [
				.product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
				"CoreDataClient",
			]
		),
    ]
)

extension Product {
	static func singleTargetLibrary(_ name: String) -> Product {
		.library(name: name, targets: [name])
	}
}
