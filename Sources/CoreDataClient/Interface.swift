// The Swift Programming Language
// https://docs.swift.org/swift-book

import DependenciesMacros
import CoreData

@DependencyClient
public struct CoreDataClient: Sendable {
	public var initialize: @Sendable(_ containerName: String, _ inMemory: Bool) async throws -> Void
	public var fetchEntities: @Sendable(_ entityName: String, _ predicate: CoreDataClient.Predicate?) async throws -> [CoreDataClient.AnyTransferable]
	public var objectExists: @Sendable(_ type: NSManagedObject.Type, _ predicate: CoreDataClient.Predicate) async throws -> CoreDataClient.AnyTransferable?
	public var insertEntity: @Sendable(_ type: NSManagedObject.Type, _ configure: CoreDataClient.Configuration) async throws -> CoreDataClient.AnyTransferable
	public var updateEntity: @Sendable(_ objectID: NSManagedObjectID, _ changes: CoreDataClient.Configuration) async throws -> CoreDataClient.AnyTransferable
	public var deleteEntity: @Sendable(_ objectID: NSManagedObjectID) async throws -> Void
}
