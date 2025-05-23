//
//  CoreDataManager.swift
//  CoreDataClient
//
//  Created by Thanh Hai Khong on 19/5/25.
//

import CoreDataClient
import CoreData

final internal class CoreDataManager: NSObject, @unchecked Sendable {
	
	private var container: NSPersistentContainer?
	
	private var context: NSManagedObjectContext? {
		guard let container = container else { return nil }
		return container.viewContext
	}
	
	private var newBackgroundContext: NSManagedObjectContext? {
		guard let container = container else { return nil }
		return container.newBackgroundContext()
	}
}

// MARK: - Public Methods

extension CoreDataManager {
	
	func initialize(_ containerName: String, _ inMemory: Bool) async throws {
		if container != nil {
			return
		}
		
		let container = NSPersistentContainer(name: containerName)
		
		if inMemory {
			container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
		}
		
		let description = NSPersistentStoreDescription()
		description.shouldMigrateStoreAutomatically = true
		description.shouldInferMappingModelAutomatically = true
		container.persistentStoreDescriptions = [description]
		
		try await container.loadPersistentStoresAsync()
		self.container = container
	}
	
	func initializeWithContainer(_ container: NSPersistentContainer) async throws -> Void {
		if self.container != nil {
			return
		}
		
		self.container = container
	}
	
	func fetchEntities(_ entityName: String, _ predicate: CoreDataClient.Predicate?) async throws -> [CoreDataClient.AnyTransferable] {
		guard let context = newBackgroundContext else {
			throw CoreDataClient.StoreError.containerNotFound
		}
		
		let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
		request.predicate = predicate?.predicate.value
		
		return try await context.safeWrite { context in
			let objects = try context.fetch(request)
			return objects.map { CoreDataClient.AnyTransferable(object: $0) }
		}
	}
	
	func objectExists(_ type: NSManagedObject.Type, _ predicate: CoreDataClient.Predicate) async throws -> CoreDataClient.AnyTransferable? {
		guard let context = newBackgroundContext else {
			throw CoreDataClient.StoreError.containerNotFound
		}
		
		let request = NSFetchRequest<NSManagedObject>(entityName: String(describing: type))
		request.predicate = predicate.predicate.value
		request.fetchLimit = 1
		
		return try await context.safeWrite { context in
			guard let object = try context.fetch(request).first else {
				return nil
			}
			
			return CoreDataClient.AnyTransferable(object: object)
		}
	}
	
	func insertEntity(_ type: NSManagedObject.Type, _ configuration: CoreDataClient.Configuration) async throws -> CoreDataClient.AnyTransferable {
		guard let container = container, let context = newBackgroundContext else {
			throw CoreDataClient.StoreError.containerNotFound
		}
		
		let entityName = String(describing: type)
		guard let entityDescription = container.managedObjectModel.entitiesByName[entityName] else {
			throw CoreDataClient.StoreError.entityNotFound(entityName)
		}
		
		return try await context.safeWrite { context in
			let object = NSManagedObject(entity: entityDescription, insertInto: context)
			try configuration.apply(to: object)
			
			return CoreDataClient.AnyTransferable(object: object)
		}
	}
	
	func updateEntity(_ objectID: NSManagedObjectID, _ changes: CoreDataClient.Configuration) async throws -> CoreDataClient.AnyTransferable {
		guard let context = newBackgroundContext else {
			throw CoreDataClient.StoreError.containerNotFound
		}
		
		return try await context.safeWrite { context in
			let object = try context.existingObject(with: objectID)
			try changes.apply(to: object)
			
			return CoreDataClient.AnyTransferable(object: object)
		}
	}
	
	func deleteEntity(_ objectID: NSManagedObjectID) async throws {
		guard let context = newBackgroundContext else {
			throw CoreDataClient.StoreError.containerNotFound
		}
		
		let object = try context.existingObject(with: objectID)
		
		try await context.safeWrite { context in
			context.delete(object)
		}
	}
}
