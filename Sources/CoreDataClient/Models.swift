//
//  Models.swift
//  CoreDataClient
//
//  Created by Thanh Hai Khong on 19/5/25.
//

import Foundation
import CoreData

// MARK: - CoreDataClientEvent

extension CoreDataClient {
	public struct Event: Sendable, Equatable {
		public enum `Type`: Sendable, Equatable {
			case inserted(NSManagedObject.Type)
			case updated(NSManagedObject.Type)
			case deleted(NSManagedObject.Type)
			
			public static func == (lhs: Type, rhs: Type) -> Bool {
				switch (lhs, rhs) {
				case (.inserted(let leftType), .inserted(let rightType)),
					(.updated(let leftType), .updated(let rightType)),
					(.deleted(let leftType), .deleted(let rightType)):
					return leftType == rightType
				default:
					return false
				}
			}
		}
		
		public let type: Type
		public let changed: AnyTransferable
		
		public init(type: Type, changed: AnyTransferable) {
			self.type = type
			self.changed = changed
		}
	}
}

// MARK: - AnySendable

extension CoreDataClient {
	public struct AnySendable: Sendable, Equatable {
		public let value: any Sendable
		
		public init<T: Sendable>(value: T) {
			self.value = value
		}
		
		public static func == (lhs: AnySendable, rhs: AnySendable) -> Bool {
			// Use a simple equality check for Sendable types
			return String(describing: lhs.value) == String(describing: rhs.value)
		}
	}
}

// MARK: - StoreError

extension CoreDataClient {
	
	public enum `Error`: Swift.Error, Sendable, CustomDebugStringConvertible {
		case containerNotFound
		case entityNotFound(String)
		case mismatchType(_ type: String, desiredType: String)
		case invalidAttribute(String)
		case noObjectFound
		case multipleObjectsFound(count: Int)
		case fetchError(underlying: Swift.Error)
		
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
	
	public struct AnyTransferable: Sendable, CustomStringConvertible, Equatable {
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
		
		public func value(forKeyPath keyPath: AnyKeyPath) -> AnySendable? {
			guard let key = keyPath._kvcKeyPathString else {
				assertionFailure("Invalid keyPath")
				return nil
			}
			
			return attributes[key]
		}
		
		public var description: String {
			let indent = "    " // 4 spaces
			let lines = attributes
				.sorted(by: { $0.key < $1.key })
				.map { key, value in
					let formatted: String
					
					switch value.value {
					case let str as String:
						formatted = "\"\(str)\""
						
					case let date as Date:
						let formatter = ISO8601DateFormatter()
						formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
						formatted = "\"\(formatter.string(from: date))\""
						
					case let url as URL:
						formatted = "\"\(url.absoluteString)\""
						
					case is NSNull:
						formatted = "nil"
						
					default:
						formatted = "\(value.value)"
					}
					
					return "\(indent)\(key): \(formatted)"
				}
			
			return """
   AnyTransferable {
   \(lines.joined(separator: ",\n"))
   }
   """
		}
	}
}

// MARK: - Configuration

extension CoreDataClient {
	
	public struct Configuration: Sendable, CustomStringConvertible {
		private let objectID: NSManagedObjectID?
		private var attributes: [String: AnySendable] = [:]
		
		public init(objectID: NSManagedObjectID? = nil) {
			self.objectID = objectID
		}
		
		public mutating func setValue<T: NSManagedObject, V>(_ value: V?, forKeyPath keyPath: KeyPath<T, V>) {
			guard let key = keyPath._kvcKeyPathString else {
				assertionFailure("Invalid keyPath")
				return
			}
			
			attributes[key] = value.map { CoreDataClient.valueToSendable($0) } ?? AnySendable(value: NSNull())
		}
		
		public func value(forKeyPath keyPath: AnyKeyPath) -> AnySendable? {
			guard let key = keyPath._kvcKeyPathString else {
				assertionFailure("Invalid keyPath")
				return nil
			}
			
			return attributes[key]
		}
		
		public func apply(to object: NSManagedObject) throws {
			for (key, value) in attributes {
				guard object.entity.attributesByName[key] != nil else {
					throw Error.invalidAttribute(key)
				}
				
				if let _ = value.value as? NSNull {
					object.setValue(nil, forKey: key)
				} else if let anyImmutableArray = value.value as? AnyImmutableArray {
					let array = anyImmutableArray.rawValue
					object.setValue(array, forKey: key)
				} else {
					object.setValue(value.value, forKey: key)
				}
			}
		}

		public func applyDiff(to object: NSManagedObject) throws {
			for (key, value) in attributes {
				guard object.entity.attributesByName[key] != nil else {
					throw Error.invalidAttribute(key)
				}
				
				if let anyImmutableArray = value.value as? AnyImmutableArray, let originalArray = object.value(forKey: key) as? NSArray {
					let array = anyImmutableArray.rawValue
					let filteredOriginal = originalArray.filter { !array.contains($0) }
					object.setValue(NSArray(array: filteredOriginal), forKey: key)
				}
			}
		}
		
		public static func from(_ object: NSManagedObject) -> Configuration {
			var config = Configuration(objectID: object.objectID)
			for (key, _) in object.entity.attributesByName {
				let attrValue = object.value(forKey: key)
				config.attributes[key] = CoreDataClient.valueToSendable(attrValue ?? NSNull())
			}
			return config
		}
		
		public var description: String {
			let indent = "    "
			let lines = attributes
				.sorted(by: { $0.key < $1.key })
				.map { key, value in
					let formatted: String
					
					switch value.value {
					case let str as String:
						formatted = "\"\(str)\""
					case let date as Date:
						let formatter = ISO8601DateFormatter()
						formatted = "\"\(formatter.string(from: date))\""
					case let url as URL:
						formatted = "\"\(url.absoluteString)\""
					case is NSNull:
						formatted = "nil"
					default:
						formatted = "\(value.value)"
					}
					
					return "\(indent)\(key): \(formatted)"
				}
			
			return """
				Configuration {
				\(lines.joined(separator: ",\n"))
				}
			"""
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
	/// Check if an array attribute contains a given element (e.g., ANY songIDs == uuid)
	public static func whereArrayContains<Root, Element>(
		_ keyPath: KeyPath<Root, [Element]>,
		contains element: Element
	) -> CoreDataClient.PredicateComponent {
		let key = CoreDataClient.AnyKeyPathable(keyPath)
		return CoreDataClient.ComparisonPredicateComponent(
			format: "ANY \(key.stringValue) == %@",
			arguments: [element]
		)
	}
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
	
	/// Equality check for relationship's nested property (to-one).
	public static func whereRelationship<Root, Related, Value>(
		_ relationKeyPath: KeyPath<Root, Related>,
		keyPath: KeyPath<Related, Value>,
		equals value: Any,
		caseInsensitive: Bool = false
	) -> CoreDataClient.PredicateComponent {
		let fullKeyPath = NSExpression(forKeyPath: relationKeyPath).keyPath + "." + NSExpression(forKeyPath: keyPath).keyPath
		let expression = NSExpression(forKeyPath: fullKeyPath)
		let valueExpression = NSExpression(forConstantValue: value)
		let predicate = NSComparisonPredicate(
			leftExpression: expression,
			rightExpression: valueExpression,
			modifier: .direct,
			type: .equalTo,
			options: caseInsensitive ? .caseInsensitive : []
		)
		return CoreDataClient.ComparisonPredicateComponent(format: predicate.predicateFormat, arguments: [])
	}
	
	/// Contains check for to-many relationship using SUBQUERY (e.g., ANY related.name == "value").
	public static func whereToMany<Root, Related>(
		_ relationKeyPath: KeyPath<Root, Set<Related>>,
		matching format: String,
		arguments: [Any]
	) -> CoreDataClient.PredicateComponent {
		let keyPathString = NSExpression(forKeyPath: relationKeyPath).keyPath
		let predicateFormat = "SUBQUERY(\(keyPathString), $r, $r \(format)).@count > 0"
		return CoreDataClient.ComparisonPredicateComponent(
			format: predicateFormat,
			arguments: arguments
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
			
		case let array as NSArray:
			return AnySendable(value: AnyImmutableArray(array))
			
		case let null as NSNull:
			return AnySendable(value: null)
			
		default:
			fatalError("AnySendable: Unsupported type \(type(of: value))")
		}
	}
}

// MARK: - AnyImmutableArray

extension CoreDataClient {
	
	public struct AnyImmutableArray: @unchecked Sendable {
		private let array: NSArray
		
		public var rawValue: NSArray {
			array.copy() as! NSArray
		}
		
		public init(_ array: NSArray) {
			self.array = array
		}
	}
}
