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
			fetchEntities: { type, predicate in
				try await actor.fetchEntities(type, predicate)
			},
			objectExists: { type, predicate in
				try await actor.objectExists(type, predicate)
			},
			insertEntity: { type, configuration in
				try await actor.insertEntity(type, configuration)
			},
			updateEntities: { type, changes in
				try await actor.updateEntities(type, changes: changes)
			},
			updateEntity: { objectID, changes in
				try await actor.updateEntity(objectID, changes: changes)
			},
			deleteEntity: { objectID in
				try await actor.deleteEntity(objectID)
			},
			observeChanges: {
				await actor.observeChanges()
			}
		)
	}()
}
