//
//  Extensions.swift
//  CoreDataClient
//
//  Created by Thanh Hai Khong on 19/5/25.
//

import Foundation
import CoreData

extension NSPersistentContainer {
	func loadPersistentStoresAsync() async throws {
		try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
			self.loadPersistentStores { _, error in
				if let error = error {
					continuation.resume(throwing: error)
				} else {
					continuation.resume()
				}
			}
		}
	}
}

extension NSManagedObjectContext {
	func safeWrite<T>(_ block: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
		try await self.perform {
			let result = try block(self)
			if self.hasChanges {
				try self.save()
			}
			return result
		}
	}
}
