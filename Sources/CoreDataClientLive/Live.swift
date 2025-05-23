//
//  Live.swift
//  CoreDataClient
//
//  Created by Thanh Hai Khong on 19/5/25.
//

import Dependencies
import CoreDataClient
import CoreData

extension CoreDataClient: DependencyKey {
	public static let liveValue: CoreDataClient = {
		let actor = CoreDataActor()
		return CoreDataClient(
			initialize: { containerName, inMemory in
				try await actor.initialize(containerName, inMemory)
			},
			initializeWithContainer: { container in
				try await actor.initializeWithContainer(container)
			},
			fetchEntities: { entityName, predicate in
				try await actor.fetchEntities(entityName, predicate)
			},
			objectExists: { type, predicate in
				try await actor.objectExists(type, predicate)
			},
			insertEntity: { type, configuration in
				try await actor.insertEntity(type, configuration)
			},
			updateEntity: { objectID, changes in
				try await actor.updateEntity(objectID, changes: changes)
			},
			deleteEntity: { objectID in
				try await actor.deleteEntity(objectID)
			}
		)
	}()
}
