import Foundation

/// HTTP 请求方法
public enum HTTPMethod: String, Sendable {
    case GET
    case POST
    case PATCH
    case DELETE
}

/// Gmail API 客户端（actor 保证线程安全）
public actor GmailAPIClient {
    private let config: GmailConfig
    private let session: URLSession
    private let decoder: JSONDecoder

    /// 可变的 accessToken（支持刷新）
    private var currentAccessToken: String

    /// Token 刷新回调（让宿主 App 持久化新 token）
    public var onTokenRefreshed: (@Sendable (String) -> Void)?

    public init(config: GmailConfig) {
        self.config = config
        self.currentAccessToken = config.accessToken

        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = config.timeout
        configuration.timeoutIntervalForResource = config.timeout * 2
        self.session = URLSession(configuration: configuration)

        self.decoder = JSONDecoder()
    }

    /// 便捷初始化
    public init(accessToken: String, refreshToken: String? = nil, clientId: String? = nil, clientSecret: String? = nil) {
        self.init(config: GmailConfig(
            accessToken: accessToken,
            refreshToken: refreshToken,
            clientId: clientId,
            clientSecret: clientSecret
        ))
    }

    /// 更新 access token
    public func updateAccessToken(_ token: String) {
        currentAccessToken = token
    }

    // MARK: - Public API Methods

    /// 发送 GET 请求
    public func get(
        path: String,
        queryParams: [String: String]? = nil
    ) async throws -> Data {
        try await requestWithRetry(method: .GET, path: path, queryParams: queryParams)
    }

    /// 发送 POST 请求
    public func post(
        path: String,
        body: [String: Any]? = nil
    ) async throws -> Data {
        try await requestWithRetry(method: .POST, path: path, body: body)
    }

    /// 发送 PATCH 请求
    public func patch(
        path: String,
        body: [String: Any]? = nil
    ) async throws -> Data {
        try await requestWithRetry(method: .PATCH, path: path, body: body)
    }

    /// 发送 DELETE 请求
    public func delete(
        path: String
    ) async throws -> Data {
        try await requestWithRetry(method: .DELETE, path: path)
    }

    // MARK: - Private Methods

    /// 带自动重试的请求（401 时刷新 token 后重试一次）
    private func requestWithRetry(
        method: HTTPMethod,
        path: String,
        queryParams: [String: String]? = nil,
        body: [String: Any]? = nil
    ) async throws -> Data {
        do {
            return try await request(method: method, path: path, queryParams: queryParams, body: body)
        } catch GmailError.unauthorized {
            // 尝试刷新 token
            if config.canRefreshToken {
                try await refreshAccessToken()
                return try await request(method: method, path: path, queryParams: queryParams, body: body)
            }
            throw GmailError.unauthorized
        }
    }

    private func request(
        method: HTTPMethod,
        path: String,
        queryParams: [String: String]? = nil,
        body: [String: Any]? = nil
    ) async throws -> Data {
        let url = try buildURL(path: path, queryParams: queryParams)
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue

        // 设置请求头
        request.setValue("Bearer \(currentAccessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("GmailMCPServer-Swift/1.0.0", forHTTPHeaderField: "User-Agent")

        // 设置请求体
        if let body = body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        // 发送请求
        let (data, response) = try await session.data(for: request)

        // 检查响应
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GmailError.networkError(URLError(.badServerResponse))
        }

        // 处理错误响应
        try handleHTTPResponse(statusCode: httpResponse.statusCode, data: data)

        return data
    }

    private func buildURL(path: String, queryParams: [String: String]?) throws -> URL {
        var urlString = config.baseURL + path

        if let queryParams = queryParams, !queryParams.isEmpty {
            let queryString = queryParams
                .map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }
                .joined(separator: "&")
            urlString += "?\(queryString)"
        }

        guard let url = URL(string: urlString) else {
            throw GmailError.invalidURL(urlString)
        }

        return url
    }

    private func handleHTTPResponse(statusCode: Int, data: Data) throws {
        switch statusCode {
        case 200..<300:
            return
        case 401:
            throw GmailError.unauthorized
        case 403:
            throw GmailError.forbidden
        case 404:
            if let errorResponse = try? decoder.decode(GmailAPIErrorResponse.self, from: data) {
                throw GmailError.notFound(errorResponse.error.message)
            }
            throw GmailError.notFound("Resource not found")
        case 429:
            throw GmailError.rateLimitExceeded
        case 400:
            if let errorResponse = try? decoder.decode(GmailAPIErrorResponse.self, from: data) {
                throw GmailError.validationError(errorResponse.error.message)
            }
            throw GmailError.validationError("Bad request")
        default:
            if let errorResponse = try? decoder.decode(GmailAPIErrorResponse.self, from: data) {
                throw GmailError.gmailAPIError(code: errorResponse.error.code, message: errorResponse.error.message)
            }
            throw GmailError.httpError(statusCode: statusCode, message: "Unknown error")
        }
    }

    // MARK: - Token Refresh

    private func refreshAccessToken() async throws {
        guard let refreshToken = config.refreshToken,
              let clientId = config.clientId,
              let clientSecret = config.clientSecret else {
            throw GmailError.tokenRefreshFailed("Missing refresh token or client credentials")
        }

        guard let url = URL(string: GmailConfig.tokenRefreshURL) else {
            throw GmailError.tokenRefreshFailed("Invalid token refresh URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let bodyString = [
            "grant_type=refresh_token",
            "refresh_token=\(refreshToken)",
            "client_id=\(clientId)",
            "client_secret=\(clientSecret)"
        ].joined(separator: "&")
        request.httpBody = bodyString.data(using: .utf8)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw GmailError.tokenRefreshFailed(message)
        }

        let tokenResponse = try decoder.decode(TokenRefreshResponse.self, from: data)
        currentAccessToken = tokenResponse.access_token

        // 通知宿主 App
        onTokenRefreshed?(tokenResponse.access_token)
    }
}

// MARK: - Response Extensions

extension Data {
    /// 转换为 JSON 字符串
    var jsonString: String {
        String(data: self, encoding: .utf8) ?? "{}"
    }
}
