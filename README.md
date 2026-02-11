# GmailMCPServer

Gmail MCP Server Swift SDK - 基于 [MCP Swift SDK](https://github.com/modelcontextprotocol/swift-sdk) 的 Gmail API 集成。

参考 [Gmail-MCP-Server](https://github.com/GongRzhe/Gmail-MCP-Server) (TypeScript) 用 Swift 实现，遵循 [MCPServerProtocol](https://github.com/modelcontextprotocol/swift-sdk) 标准协议。

## 功能

实现了 19 个 Gmail MCP 工具，覆盖邮件收发、标签管理、过滤器配置和批量操作。

### 工具列表

| 类别 | 工具 |
|------|------|
| **邮件 (6)** | `gmail_send_email`, `gmail_read_email`, `gmail_search_emails`, `gmail_modify_email`, `gmail_delete_email`, `gmail_download_attachment` |
| **标签 (5)** | `gmail_list_labels`, `gmail_create_label`, `gmail_update_label`, `gmail_delete_label`, `gmail_get_or_create_label` |
| **过滤器 (5)** | `gmail_create_filter`, `gmail_list_filters`, `gmail_get_filter`, `gmail_delete_filter`, `gmail_create_filter_from_template` |
| **草稿 (1)** | `gmail_draft_email` |
| **批量操作 (2)** | `gmail_batch_modify_emails`, `gmail_batch_delete_emails` |

### 过滤器模板

`gmail_create_filter_from_template` 支持 6 种预设模板：

| 模板 | 说明 |
|------|------|
| `fromSender` | 按发件人过滤 |
| `withSubject` | 按主题关键词过滤 |
| `withAttachments` | 过滤带附件的邮件 |
| `largeEmails` | 过滤超过指定大小的邮件 |
| `containingText` | 按正文内容过滤 |
| `mailingList` | 过滤邮件列表 |

## 安装

### Swift Package Manager

在 `Package.swift` 中添加依赖：

```swift
dependencies: [
    .package(url: "https://github.com/zhan2333/gmail-mcp-server-swift.git", from: "1.0.0"),
]
```

然后在 target 中添加：

```swift
.target(
    name: "YourTarget",
    dependencies: ["GmailMCPServer"]
),
```

## 使用

### 基础用法

```swift
import GmailMCPServer
import MCP

// 1. 创建 Server
let server = GmailMCPServer(accessToken: "ya29.xxx")

// 2. 启动
try await server.start()

// 3. 获取工具列表
let tools = server.getTools()
print("Available tools: \(tools.count)")  // 19

// 4. 执行工具 - 搜索邮件
let result = try await server.executeTool(
    name: "gmail_search_emails",
    arguments: [
        "query": .string("from:github.com"),
        "maxResults": .int(5)
    ]
)

// 5. 执行工具 - 发送邮件
let sendResult = try await server.executeTool(
    name: "gmail_send_email",
    arguments: [
        "to": .array([.string("recipient@example.com")]),
        "subject": .string("Hello from MCP"),
        "body": .string("This email was sent via Gmail MCP Server.")
    ]
)
```

### 带 Token 刷新的用法

```swift
let server = GmailMCPServer(
    accessToken: "ya29.xxx",
    refreshToken: "1//xxx",
    clientId: "xxx.apps.googleusercontent.com",
    clientSecret: "GOCSPX-xxx"
)

// 监听 Token 刷新事件，持久化新 Token
await server.client.updateOnTokenRefreshed { newToken in
    KeychainManager.shared.saveGmailAccessToken(newToken)
}

try await server.start()
```

### 集成到 MCP Manager (PeerBox)

```swift
// 注册到 MCPManager
MCPManager.shared.registerServer(server)
```

## 配置

### OAuth 2.0 凭证

从 [Google Cloud Console](https://console.cloud.google.com/apis/credentials) 获取 OAuth 2.0 凭证，并启用 Gmail API。

```swift
// 方式 1: 仅 Access Token（无自动刷新）
let server = GmailMCPServer(accessToken: "ya29.xxx")

// 方式 2: 完整 OAuth 配置（支持自动刷新）
let config = GmailConfig(
    accessToken: "ya29.xxx",
    refreshToken: "1//xxx",       // 可选
    clientId: "xxx.apps",         // 可选
    clientSecret: "GOCSPX-xxx",   // 可选
    timeout: 30                   // 可选，默认 30s
)
let server = GmailMCPServer(config: config)

// 方式 3: 从环境变量
// 需要设置 GMAIL_ACCESS_TOKEN，可选 GMAIL_REFRESH_TOKEN, GMAIL_CLIENT_ID, GMAIL_CLIENT_SECRET
let config = try GmailConfig.fromEnvironment()
let server = GmailMCPServer(config: config)
```

### Token 自动刷新

当 `refreshToken`、`clientId`、`clientSecret` 三者都提供时，API 客户端会在收到 401 响应时自动刷新 Token 并重试请求。

## 架构

```
Sources/GmailMCPServer/
├── GmailMCPServer.swift         # 主服务器 (MCPServerProtocol)
├── GmailAPIClient.swift         # HTTP 客户端 (actor, 自动 Token 刷新)
├── GmailConfig.swift            # 配置
├── GmailEmailBuilder.swift      # RFC 2822 邮件构造 + base64url 编码
├── Models/
│   ├── GmailError.swift         # 错误类型
│   └── GmailModels.swift        # API 响应模型
├── Tools/                       # MCP 工具定义
│   ├── GmailTools.swift         # 工具注册表 (19 个)
│   ├── MessageTools.swift       # 邮件工具
│   ├── LabelTools.swift         # 标签工具
│   ├── FilterTools.swift        # 过滤器工具
│   ├── DraftTools.swift         # 草稿工具
│   └── BatchTools.swift         # 批量操作工具
└── Utils/
    └── ValueExtensions.swift    # MCP Value 扩展
```

## 系统要求

- Swift 6.0+
- iOS 16.0+ / macOS 13.0+

## 依赖

- [MCP Swift SDK](https://github.com/modelcontextprotocol/swift-sdk) (0.10.0+)

## License

MIT
