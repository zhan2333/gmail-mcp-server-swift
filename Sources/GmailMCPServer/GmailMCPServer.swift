import Foundation
import FlooMCP

// MARK: - Gmail MCP Server

/// Gmail MCP Server 实现
public final class GmailMCPServer: MCPServerProtocol, @unchecked Sendable {
    // MARK: - Properties

    public let name = "gmail"
    public let version = "1.0.0"
    public private(set) var isRunning = false

    private let apiClient: GmailAPIClient
    private var registeredTools: [String: RegisteredTool] = [:]
    private let toolsQueue = DispatchQueue(label: "com.gmail.mcp.tools", attributes: .concurrent)
    private var toolsInitialized = false

    // MARK: - Initialization

    /// 使用配置初始化
    public init(config: GmailConfig) {
        self.apiClient = GmailAPIClient(config: config)
        initializeTools()
    }

    /// 使用 Access Token 初始化
    public init(accessToken: String, refreshToken: String? = nil, clientId: String? = nil, clientSecret: String? = nil) {
        self.apiClient = GmailAPIClient(config: GmailConfig(
            accessToken: accessToken,
            refreshToken: refreshToken,
            clientId: clientId,
            clientSecret: clientSecret
        ))
        initializeTools()
    }

    private func initializeTools() {
        toolsQueue.async(flags: .barrier) { [weak self] in
            guard let self = self, !self.toolsInitialized else { return }
            self.registerAllToolsInternal()
            self.toolsInitialized = true
        }
    }

    // MARK: - MCPServerProtocol Implementation

    public func start() async throws {
        isRunning = true
    }

    public func stop() async {
        isRunning = false
    }

    public func getTools() -> [Tool] {
        toolsQueue.sync {
            Array(registeredTools.values.map { $0.tool })
        }
    }

    public func executeTool(name: String, arguments: [String: Value]) async throws -> [Tool.Content] {
        let handler: ToolHandler? = toolsQueue.sync {
            registeredTools[name]?.handler
        }

        guard let handler = handler else {
            throw GmailError.toolNotFound(name)
        }

        let result = try await handler(arguments)
        return [.text(result)]
    }

    // MARK: - Tool Registration

    private func registerAllToolsInternal() {
        // 标签工具 (5)
        for tool in LabelTools.all(apiClient: apiClient) {
            registeredTools[tool.sdkTool.name] = RegisteredTool(
                tool: tool.sdkTool,
                handler: tool.handler
            )
        }

        // 邮件工具 (6)
        for tool in MessageTools.all(apiClient: apiClient) {
            registeredTools[tool.sdkTool.name] = RegisteredTool(
                tool: tool.sdkTool,
                handler: tool.handler
            )
        }

        // 草稿工具 (1)
        for tool in DraftTools.all(apiClient: apiClient) {
            registeredTools[tool.sdkTool.name] = RegisteredTool(
                tool: tool.sdkTool,
                handler: tool.handler
            )
        }

        // 过滤器工具 (5)
        for tool in FilterTools.all(apiClient: apiClient) {
            registeredTools[tool.sdkTool.name] = RegisteredTool(
                tool: tool.sdkTool,
                handler: tool.handler
            )
        }

        // 批量操作工具 (2)
        for tool in BatchTools.all(apiClient: apiClient) {
            registeredTools[tool.sdkTool.name] = RegisteredTool(
                tool: tool.sdkTool,
                handler: tool.handler
            )
        }
    }

    /// 手动注册自定义工具
    public func registerCustomTool(_ tool: SimpleTool) {
        toolsQueue.async(flags: .barrier) { [weak self] in
            self?.registeredTools[tool.sdkTool.name] = RegisteredTool(
                tool: tool.sdkTool,
                handler: tool.handler
            )
        }
    }

    /// 获取已注册的工具名称列表
    public func getToolNames() -> [String] {
        toolsQueue.sync {
            Array(registeredTools.keys).sorted()
        }
    }

    /// 获取 API 客户端（供外部配置 token 回调等）
    public var client: GmailAPIClient {
        apiClient
    }
}
