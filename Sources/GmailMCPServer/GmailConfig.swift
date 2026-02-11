import Foundation

/// Gmail MCP Server 配置
public struct GmailConfig: Sendable {
    /// OAuth 2.0 Access Token
    public let accessToken: String

    /// OAuth 2.0 Refresh Token（可选，用于自动刷新）
    public let refreshToken: String?

    /// OAuth 2.0 Client ID（刷新 token 时需要）
    public let clientId: String?

    /// OAuth 2.0 Client Secret（刷新 token 时需要）
    public let clientSecret: String?

    /// API 基础 URL
    public let baseURL: String

    /// 请求超时时间（秒）
    public let timeout: TimeInterval

    /// 默认基础 URL
    public static let defaultBaseURL = "https://gmail.googleapis.com/gmail/v1"

    /// OAuth 2.0 Token 刷新 URL
    public static let tokenRefreshURL = "https://oauth2.googleapis.com/token"

    /// 默认超时时间
    public static let defaultTimeout: TimeInterval = 30

    /// 是否可以刷新 Token
    public var canRefreshToken: Bool {
        refreshToken != nil && clientId != nil && clientSecret != nil
    }

    public init(
        accessToken: String,
        refreshToken: String? = nil,
        clientId: String? = nil,
        clientSecret: String? = nil,
        baseURL: String = GmailConfig.defaultBaseURL,
        timeout: TimeInterval = GmailConfig.defaultTimeout
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.clientId = clientId
        self.clientSecret = clientSecret
        self.baseURL = baseURL
        self.timeout = timeout
    }

    /// 验证配置
    public func validate() throws {
        guard !accessToken.isEmpty else {
            throw GmailError.missingAccessToken
        }
    }

    /// 从环境变量创建配置
    public static func fromEnvironment() throws -> GmailConfig {
        guard let accessToken = ProcessInfo.processInfo.environment["GMAIL_ACCESS_TOKEN"] else {
            throw GmailError.missingAccessToken
        }

        let refreshToken = ProcessInfo.processInfo.environment["GMAIL_REFRESH_TOKEN"]
        let clientId = ProcessInfo.processInfo.environment["GMAIL_CLIENT_ID"]
        let clientSecret = ProcessInfo.processInfo.environment["GMAIL_CLIENT_SECRET"]

        return GmailConfig(
            accessToken: accessToken,
            refreshToken: refreshToken,
            clientId: clientId,
            clientSecret: clientSecret
        )
    }
}
