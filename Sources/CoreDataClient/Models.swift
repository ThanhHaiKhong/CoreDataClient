//
//  Models.swift
//  CoreDataClient
//
//  Created by Thanh Hai Khong on 19/5/25.
//

import Foundation
import CoreData

// MARK: - AnySendable

extension CoreDataClient {
	public struct AnySendable: Sendable {
		public let value: any Sendable
		
		public init<T: Sendable>(value: T) {
			self.value = value
		}
	}
}

// MARK: - StoreError

extension CoreDataClient {
	
	public enum StoreError: Error, Sendable, CustomDebugStringConvertible {
		case containerNotFound
		case entityNotFound(String)
		case mismatchType(_ type: String, desiredType: String)
		case invalidAttribute(String)
		case noObjectFound
		case multipleObjectsFound(count: Int)
		case fetchError(underlying: Error)
		
		public var debugDescription: String {
			switch self {
			case .containerNotFound:
				return "Container not found."
				
			case .entityNotFound(let entityName):
				return "Entity not found: \(entityName)"
				
			case let .mismatchType(type, desiredType):
				return "Mismatch type: \(type) \(type) is not \(desiredType)"
				
			case let .invalidAttribute(attribute):
				return "Invalid attribute: \(attribute)"
				
			case .noObjectFound:
				return "No object found matching the predicate."
				
			case .multipleObjectsFound(let count):
				return "Multiple objects (\(count)) found; expected exactly one."
				
			case .fetchError(let underlying):
				return "Fetch error: \(underlying.localizedDescription)"
			}
		}
	}
}

// MARK: - AnyTransferable

extension CoreDataClient {
	
	public struct AnyTransferable: Sendable {
		public let objectID: NSManagedObjectID
		public var attributes: [String: AnySendable]
		
		public init(objectID: NSManagedObjectID, attributes: [String: AnySendable]) {
			self.objectID = objectID
			self.attributes = attributes
		}
		
		public init(object: NSManagedObject) {
			self.objectID = object.objectID
			self.attributes = [:]
			
			for (key, _) in object.entity.attributesByName {
				if let attrValue = object.value(forKey: key) {
					attributes[key] = CoreDataClient.valueToSendable(attrValue)
				}
			}
		}
		
		public func value(forKey key: String) -> AnySendable? {
			attributes[key]
		}
	}
}

// MARK: - Configuration

extension CoreDataClient {
	
	public struct Configuration: Sendable {
		private let objectID: NSManagedObjectID?
		public var attributes: [String: AnySendable] = [:]
		
		public init(objectID: NSManagedObjectID? = nil) {
			self.objectID = objectID
		}
		
		public mutating func setValue(_ value: Any?, for key: String) {
			if let value = value {
				attributes[key] = CoreDataClient.valueToSendable(value)
			} else {
				attributes[key] = AnySendable(value: NSNull())
			}
		}
		
		public mutating func setValue(_ value: Any?, for keyPath: KeyPath<NSManagedObject, Any?>) {
			guard let key = keyPath._kvcKeyPathString else {
				assertionFailure("Invalid keyPath (cannot convert to KVC string)")
				return
			}
			
			if let value = value {
				attributes[key] = CoreDataClient.valueToSendable(value)
			} else {
				attributes[key] = AnySendable(value: NSNull())
			}
		}
		
		public func apply(to entity: NSManagedObject) throws {
			for (key, value) in attributes {
				guard entity.entity.attributesByName[key] != nil else {
					throw StoreError.invalidAttribute(key)
				}
				
				if let _ = value.value as? NSNull {
					entity.setValue(nil, forKey: key)
				} else {
					entity.setValue(value.value, forKey: key)
				}
			}
		}
		
		public static func from(_ entity: NSManagedObject) -> Configuration {
			var config = Configuration(objectID: entity.objectID)
			for (key, _) in entity.entity.attributesByName {
				let attrValue = entity.value(forKey: key)
				config.attributes[key] = CoreDataClient.valueToSendable(attrValue ?? NSNull())
			}
			return config
		}
	}
}

// MARK: - AnyPredicate

extension CoreDataClient {
	
	public struct AnyPredicate: @unchecked Sendable {
		private let internalPredicate: NSPredicate
		
		public var value: NSPredicate {
			internalPredicate.copy() as! NSPredicate
		}
		
		public init(_ predicate: NSPredicate) {
			self.internalPredicate = predicate
		}
	}
}

// MARK: - Predicate Component Protocol

extension CoreDataClient {
	
	/// Protocol for components that can be converted to AnyPredicate.
	public protocol PredicateComponent: Sendable {
		var predicate: CoreDataClient.AnyPredicate { get }
	}
}

// MARK: - AnyKeyPathable

extension CoreDataClient {
	
	public struct AnyKeyPathable: @unchecked Sendable {
		private let keyPath: AnyKeyPath
		private let keyPathString: String
		
		/// Initialize with a KeyPath.
		public init<Root, Value>(_ keyPath: KeyPath<Root, Value>) {
			self.keyPath = keyPath
			self.keyPathString = NSExpression(forKeyPath: keyPath).keyPath
		}
		
		/// Get the string representation for use in NSPredicate.
		public var stringValue: String {
			keyPathString
		}
		
		/// Evaluate the key path on an object, returning the value.
		public func value<Root, Value>(for object: Root) -> Value? {
			guard let keyPath = keyPath as? KeyPath<Root, Value> else { return nil }
			return object[keyPath: keyPath]
		}
	}
}

// MARK: - PredicateBuilder

extension CoreDataClient {
	@resultBuilder
	public struct PredicateBuilder {
		public static func buildBlock(_ components: CoreDataClient.PredicateComponent...) -> CoreDataClient.AnyPredicate {
			CoreDataClient.AnyPredicate(NSCompoundPredicate(andPredicateWithSubpredicates: components.map { $0.predicate.value }))
		}
		
		public static func buildExpression(_ expr: CoreDataClient.PredicateComponent) -> CoreDataClient.PredicateComponent {
			expr
		}
		
		public static func buildEither(_ component: CoreDataClient.PredicateComponent) -> CoreDataClient.PredicateComponent {
			component
		}
		
		public static func buildOptional(_ component: CoreDataClient.PredicateComponent?) -> CoreDataClient.PredicateComponent {
			component ?? CoreDataClient.TruePredicateComponent()
		}
		
		public static func buildArray(_ components: [CoreDataClient.PredicateComponent]) -> CoreDataClient.PredicateComponent {
			CoreDataClient.CompoundPredicateComponent(type: .and, subpredicates: components.map { $0.predicate.value })
		}
	}
}

// MARK: - ComparisonPredicateComponent

extension CoreDataClient {
	/// Represents a single comparison predicate (e.g., key == value).
	public struct ComparisonPredicateComponent: CoreDataClient.PredicateComponent, Sendable {
		public let predicate: CoreDataClient.AnyPredicate
		
		public init(key: CoreDataClient.AnyKeyPathable, operator: NSComparisonPredicate.Operator, value: Any, options: NSComparisonPredicate.Options = []) {
			let left = NSExpression(forKeyPath: key.stringValue)
			let right = NSExpression(forConstantValue: value)
			let nsPredicate = NSComparisonPredicate(
				leftExpression: left,
				rightExpression: right,
				modifier: .direct,
				type: `operator`,
				options: options
			)
			self.predicate = CoreDataClient.AnyPredicate(nsPredicate)
		}
		
		public init(format: String, arguments: [Any]) {
			self.predicate = CoreDataClient.AnyPredicate(NSPredicate(format: format, argumentArray: arguments))
		}
	}
}

// MARK: - CompoundPredicateComponent

extension CoreDataClient {
	/// Represents a compound predicate (AND, OR, NOT).
	public struct CompoundPredicateComponent: CoreDataClient.PredicateComponent, Sendable {
		public let predicate: CoreDataClient.AnyPredicate
		
		public init(type: NSCompoundPredicate.LogicalType, subpredicates: [NSPredicate]) {
			self.predicate = CoreDataClient.AnyPredicate(NSCompoundPredicate(type: type, subpredicates: subpredicates))
		}
	}
}

// MARK: - TruePredicateComponent

extension CoreDataClient {
	
	/// Represents a true predicate (always evaluates to true).
	public struct TruePredicateComponent: CoreDataClient.PredicateComponent, Sendable {
		public let predicate = CoreDataClient.AnyPredicate(NSPredicate(value: true))
	}
}

// MARK: - Predicate

extension CoreDataClient {
	/// Main entry point for building predicates using the DSL.
	public struct Predicate: Sendable {
		public let predicate: CoreDataClient.AnyPredicate
		
		public init(@CoreDataClient.PredicateBuilder _ builder: () -> CoreDataClient.AnyPredicate) {
			self.predicate = builder()
		}
	}
}

// MARK: - Predicate Extensions

extension CoreDataClient.Predicate {
	/// Equal to comparison.
	public static func `where`<Root, Value>(_ keyPath: KeyPath<Root, Value>, equals value: Any, caseInsensitive: Bool = false) -> CoreDataClient.PredicateComponent {
		CoreDataClient.ComparisonPredicateComponent(
			key: CoreDataClient.AnyKeyPathable(keyPath),
			operator: .equalTo,
			value: value,
			options: caseInsensitive ? .caseInsensitive : []
		)
	}
	
	/// Not equal to comparison.
	public static func `where`<Root, Value>(_ keyPath: KeyPath<Root, Value>, notEquals value: Any, caseInsensitive: Bool = false) -> CoreDataClient.PredicateComponent {
		CoreDataClient.ComparisonPredicateComponent(
			key: CoreDataClient.AnyKeyPathable(keyPath),
			operator: .notEqualTo,
			value: value,
			options: caseInsensitive ? .caseInsensitive : []
		)
	}
	
	/// Greater than comparison.
	public static func `where`<Root, Value>(_ keyPath: KeyPath<Root, Value>, greaterThan value: Any) -> CoreDataClient.PredicateComponent {
		CoreDataClient.ComparisonPredicateComponent(
			key: CoreDataClient.AnyKeyPathable(keyPath),
			operator: .greaterThan,
			value: value
		)
	}
	
	/// Less than comparison.
	public static func `where`<Root, Value>(_ keyPath: KeyPath<Root, Value>, lessThan value: Any) -> CoreDataClient.PredicateComponent {
		CoreDataClient.ComparisonPredicateComponent(
			key: CoreDataClient.AnyKeyPathable(keyPath),
			operator: .lessThan,
			value: value
		)
	}
	
	/// Contains comparison (for strings or collections).
	public static func `where`<Root, Value>(_ keyPath: KeyPath<Root, Value>, contains value: String, caseInsensitive: Bool = false) -> CoreDataClient.PredicateComponent {
		CoreDataClient.ComparisonPredicateComponent(
			key: CoreDataClient.AnyKeyPathable(keyPath),
			operator: .contains,
			value: value,
			options: caseInsensitive ? .caseInsensitive : []
		)
	}
	
	/// IN comparison (value in a collection).
	public static func `where`<Root, Value>(_ keyPath: KeyPath<Root, Value>, `in` values: [Any]) -> CoreDataClient.PredicateComponent {
		CoreDataClient.ComparisonPredicateComponent(
			key: CoreDataClient.AnyKeyPathable(keyPath),
			operator: .in,
			value: values
		)
	}
	
	/// Custom predicate with format string.
	public static func custom(_ format: String, _ arguments: Any...) -> CoreDataClient.PredicateComponent {
		CoreDataClient.ComparisonPredicateComponent(
			format: format,
			arguments: arguments
		)
	}
	
	/// Logical AND combination.
	public static func and(_ components: CoreDataClient.PredicateComponent...) -> CoreDataClient.PredicateComponent {
		CoreDataClient.CompoundPredicateComponent(
			type: .and,
			subpredicates: components.map { $0.predicate.value }
		)
	}
	
	/// Logical OR combination.
	public static func or(_ components: CoreDataClient.PredicateComponent...) -> CoreDataClient.PredicateComponent {
		CoreDataClient.CompoundPredicateComponent(
			type: .or,
			subpredicates: components.map { $0.predicate.value }
		)
	}
	
	/// Logical NOT.
	public static func not(_ component: CoreDataClient.PredicateComponent) -> CoreDataClient.PredicateComponent {
		CoreDataClient.CompoundPredicateComponent(
			type: .not,
			subpredicates: [component.predicate.value]
		)
	}
}

// MARK: - Supporting Methods

extension CoreDataClient {
	private static func valueToSendable(_ value: Any) -> AnySendable {
		switch value {
		case let str as String:
			return AnySendable(value: str)
			
		case let int as Int:
			return AnySendable(value: int)
			
		case let int16 as Int16:
			return AnySendable(value: int16)
			
		case let int32 as Int32:
			return AnySendable(value: int32)
			
		case let int64 as Int64:
			return AnySendable(value: int64)
			
		case let double as Double:
			return AnySendable(value: double)
			
		case let float as Float:
			return AnySendable(value: float)
			
		case let decimal as NSDecimalNumber:
			return AnySendable(value: decimal)
			
		case let uuid as UUID:
			return AnySendable(value: uuid)
			
		case let bool as Bool:
			return AnySendable(value: bool)
			
		case let date as Date:
			return AnySendable(value: date)
			
		case let data as Data:
			return AnySendable(value: data)
			
		case let url as URL:
			return AnySendable(value: url)
			
		case let array as [AnySendable]:
			return AnySendable(value: array)
			
		case let null as NSNull:
			return AnySendable(value: null)
			
		default:
			fatalError("AnySendable: Unsupported type \(type(of: value))")
		}
	}
}

extension CoreDataClient {
	
	public struct AnyContainer: Sendable {
		private let internalContainer: NSPersistentContainer
		
		public var container: NSPersistentContainer {
			internalContainer
		}
		
		public init(_ container: NSPersistentContainer) {
			self.internalContainer = container
		}
	}
}
