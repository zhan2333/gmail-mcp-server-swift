import Foundation

/// Gmail MCP Server 错误类型
public enum GmailError: LocalizedError, Sendable {
    // MARK: - 配置错误
    case missingAccessToken
    case invalidConfig(String)
    case clientNotInitialized

    // MARK: - 参数错误
    case missingRequiredArgument(String)
    case invalidArgument(String, String)
    case invalidArgumentType(String, expected: String, got: String)

    // MARK: - 工具错误
    case toolNotFound(String)
    case toolExecutionFailed(String)

    // MARK: - API 错误
    case invalidURL(String)
    case networkError(Error)
    case httpError(statusCode: Int, message: String)
    case decodingError(Error)
    case encodingError(Error)

    // MARK: - Gmail 特定错误
    case gmailAPIError(code: Int, message: String)
    case rateLimitExceeded
    case unauthorized
    case forbidden
    case notFound(String)
    case validationError(String)
    case tokenRefreshFailed(String)
    case quotaExceeded
    case emailConstructionFailed(String)
    case invalidEmail(String)

    public var errorDescription: String? {
        switch self {
        case .missingAccessToken:
            return "Gmail OAuth access token is required"
        case .invalidConfig(let reason):
            return "Invalid configuration: \(reason)"
        case .clientNotInitialized:
            return "Gmail API client is not initialized"

        case .missingRequiredArgument(let name):
            return "Missing required argument: \(name)"
        case .invalidArgument(let name, let reason):
            return "Invalid argument '\(name)': \(reason)"
        case .invalidArgumentType(let name, let expected, let got):
            return "Invalid type for '\(name)': expected \(expected), got \(got)"

        case .toolNotFound(let name):
            return "Tool not found: \(name)"
        case .toolExecutionFailed(let reason):
            return "Tool execution failed: \(reason)"

        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .httpError(let statusCode, let message):
            return "HTTP error \(statusCode): \(message)"
        case .decodingError(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .encodingError(let error):
            return "Failed to encode request: \(error.localizedDescription)"

        case .gmailAPIError(let code, let message):
            return "Gmail API error [\(code)]: \(message)"
        case .rateLimitExceeded:
            return "Gmail API rate limit exceeded"
        case .unauthorized:
            return "Unauthorized: Invalid or expired access token"
        case .forbidden:
            return "Forbidden: Insufficient permissions"
        case .notFound(let resource):
            return "Not found: \(resource)"
        case .validationError(let message):
            return "Validation error: \(message)"
        case .tokenRefreshFailed(let reason):
            return "Token refresh failed: \(reason)"
        case .quotaExceeded:
            return "Gmail API quota exceeded"
        case .emailConstructionFailed(let reason):
            return "Email construction failed: \(reason)"
        case .invalidEmail(let email):
            return "Invalid email address: \(email)"
        }
    }
}

// MARK: - Gmail API Error Response

/// Gmail API 错误响应模型
struct GmailAPIErrorResponse: Decodable {
    let error: GmailAPIErrorDetail
}

struct GmailAPIErrorDetail: Decodable {
    let code: Int
    let message: String
    let errors: [GmailAPIErrorItem]?
}

struct GmailAPIErrorItem: Decodable {
    let message: String?
    let domain: String?
    let reason: String?
}
