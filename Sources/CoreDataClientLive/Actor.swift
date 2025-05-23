//
//  Actor.swift
//  CoreDataClient
//
//  Created by Thanh Hai Khong on 19/5/25.
//

import CoreDataClient
import CoreData

actor CoreDataActor {
	
	private let manager = CoreDataManager()

	func initialize(_ containerName: String, _ inMemory: Bool) async throws {
		try await manager.initialize(containerName, inMemory)
	}
	
	func initializeWithContainer(_ container: NSPersistentContainer) async throws -> Void {
		try await manager.initializeWithContainer(container)
	}
	
	func fetchEntities(_ type: NSManagedObject.Type, _ predicate: CoreDataClient.Predicate?) async throws -> [CoreDataClient.AnyTransferable] {
		try await manager.fetchEntities(type, predicate)
	}
	
	func objectExists(_ type: NSManagedObject.Type, _ predicate: CoreDataClient.Predicate) async throws -> CoreDataClient.AnyTransferable? {
		try await manager.objectExists(type, predicate)
	}
	
	func insertEntity(_ type: NSManagedObject.Type, _ configuration: CoreDataClient.Configuration) async throws -> CoreDataClient.AnyTransferable {
		try await manager.insertEntity(type, configuration)
	}
	
	func updateEntity(_ objectID: NSManagedObjectID, changes: CoreDataClient.Configuration) async throws -> CoreDataClient.AnyTransferable {
		try await manager.updateEntity(objectID, changes)
	}
	
	func deleteEntity(_ objectID: NSManagedObjectID) async throws {
		try await manager.deleteEntity(objectID)
	}
}
