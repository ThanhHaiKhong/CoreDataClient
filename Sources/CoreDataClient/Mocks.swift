//
//  Mocks.swift
//  CoreDataClient
//
//  Created by Thanh Hai Khong on 19/5/25.
//

import Dependencies

extension DependencyValues {
	public var coreDataClient: CoreDataClient {
		get { self[CoreDataClient.self] }
		set { self[CoreDataClient.self] = newValue }
	}
}

extension CoreDataClient: TestDependencyKey {
	public static var testValue: CoreDataClient {
		CoreDataClient()
	}
	
	public static var previewValue: CoreDataClient {
		CoreDataClient()
	}
}
