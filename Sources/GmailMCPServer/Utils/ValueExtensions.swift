import Foundation
import FlooMCP

// MARK: - Value 转换为 Any

extension Value {
    /// 转换为 Swift 原生类型
    public func toAny() -> Any? {
        switch self {
        case .null:
            return nil
        case .bool(let value):
            return value
        case .int(let value):
            return value
        case .double(let value):
            return value
        case .string(let value):
            return value
        case .data(_, let value):
            return value
        case .array(let value):
            return value.map { $0.toAny() }
        case .object(let value):
            return value.mapValues { $0.toAny() }
        }
    }
}

// MARK: - Any 转换为 Value

extension Value {
    /// 从 Swift 原生类型创建 Value
    public static func from(_ any: Any?) -> Value {
        guard let any = any else {
            return .null
        }

        switch any {
        case let value as Bool:
            return .bool(value)
        case let value as Int:
            return .int(value)
        case let value as Double:
            return .double(value)
        case let value as String:
            return .string(value)
        case let value as Data:
            return .data(value)
        case let value as [Any]:
            return .array(value.map { Value.from($0) })
        case let value as [String: Any]:
            return .object(value.mapValues { Value.from($0) })
        default:
            return .string(String(describing: any))
        }
    }
}

// MARK: - 参数提取帮助器

/// 从 Value 字典中提取参数的帮助器
public struct ArgumentExtractor {
    private let arguments: [String: Value]

    public init(_ arguments: [String: Value]) {
        self.arguments = arguments
    }

    /// 获取必需的字符串参数
    public func requiredString(_ key: String) throws -> String {
        guard let value = arguments[key] else {
            throw GmailError.missingRequiredArgument(key)
        }
        guard let stringValue = value.stringValue else {
            throw GmailError.invalidArgumentType(key, expected: "string", got: value.typeName)
        }
        return stringValue
    }

    /// 获取可选的字符串参数
    public func optionalString(_ key: String) -> String? {
        arguments[key]?.stringValue
    }

    /// 获取必需的整数参数
    public func requiredInt(_ key: String) throws -> Int {
        guard let value = arguments[key] else {
            throw GmailError.missingRequiredArgument(key)
        }
        guard let intValue = value.intValue else {
            throw GmailError.invalidArgumentType(key, expected: "integer", got: value.typeName)
        }
        return intValue
    }

    /// 获取可选的整数参数
    public func optionalInt(_ key: String) -> Int? {
        arguments[key]?.intValue
    }

    /// 获取可选的布尔参数
    public func optionalBool(_ key: String) -> Bool? {
        arguments[key]?.boolValue
    }

    /// 获取必需的对象参数
    public func requiredObject(_ key: String) throws -> [String: Value] {
        guard let value = arguments[key] else {
            throw GmailError.missingRequiredArgument(key)
        }
        guard let objectValue = value.objectValue else {
            throw GmailError.invalidArgumentType(key, expected: "object", got: value.typeName)
        }
        return objectValue
    }

    /// 获取可选的对象参数
    public func optionalObject(_ key: String) -> [String: Value]? {
        arguments[key]?.objectValue
    }

    /// 获取必需的数组参数
    public func requiredArray(_ key: String) throws -> [Value] {
        guard let value = arguments[key] else {
            throw GmailError.missingRequiredArgument(key)
        }
        guard let arrayValue = value.arrayValue else {
            throw GmailError.invalidArgumentType(key, expected: "array", got: value.typeName)
        }
        return arrayValue
    }

    /// 获取可选的数组参数
    public func optionalArray(_ key: String) -> [Value]? {
        arguments[key]?.arrayValue
    }

    /// 获取必需的字符串数组参数
    public func requiredStringArray(_ key: String) throws -> [String] {
        let array = try requiredArray(key)
        return array.compactMap { $0.stringValue }
    }

    /// 获取可选的字符串数组参数
    public func optionalStringArray(_ key: String) -> [String]? {
        guard let array = arguments[key]?.arrayValue else { return nil }
        let strings = array.compactMap { $0.stringValue }
        return strings.isEmpty ? nil : strings
    }

    /// 检查参数是否存在
    public func has(_ key: String) -> Bool {
        if let value = arguments[key], !value.isNull {
            return true
        }
        return false
    }
}

// MARK: - Value Type Name

extension Value {
    /// 获取类型名称
    var typeName: String {
        switch self {
        case .null: return "null"
        case .bool: return "boolean"
        case .int: return "integer"
        case .double: return "number"
        case .string: return "string"
        case .data: return "data"
        case .array: return "array"
        case .object: return "object"
        }
    }
}

// MARK: - Value 转 JSON

extension Value {
    /// 转换为 JSON Data
    public func toJSONData() throws -> Data {
        let any = self.toAny() ?? NSNull()
        return try JSONSerialization.data(withJSONObject: any)
    }

    /// 转换为 JSON 字符串
    public func toJSONString() throws -> String {
        let data = try toJSONData()
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}

// MARK: - [String: Value] 转 [String: Any]

extension Dictionary where Key == String, Value == FlooMCP.Value {
    /// 转换为 [String: Any]
    public func toAnyDict() -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, value) in self {
            if let anyValue = value.toAny() {
                result[key] = anyValue
            }
        }
        return result
    }
}
