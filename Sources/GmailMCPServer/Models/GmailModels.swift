import Foundation

// MARK: - Message Models

/// Gmail 消息列表响应
struct GmailMessageListResponse: Decodable {
    let messages: [GmailMessageRef]?
    let nextPageToken: String?
    let resultSizeEstimate: Int?
}

/// Gmail 消息引用（仅 id + threadId）
struct GmailMessageRef: Decodable {
    let id: String
    let threadId: String?
}

// MARK: - Label Models

/// Gmail 标签
struct GmailLabel: Decodable {
    let id: String?
    let name: String?
    let type: String?
    let messageListVisibility: String?
    let labelListVisibility: String?
    let messagesTotal: Int?
    let messagesUnread: Int?
    let color: GmailLabelColor?
}

struct GmailLabelColor: Decodable {
    let textColor: String?
    let backgroundColor: String?
}

/// Gmail 标签列表响应
struct GmailLabelsListResponse: Decodable {
    let labels: [GmailLabel]?
}

// MARK: - Filter Models

/// Gmail 过滤器
struct GmailFilter: Decodable {
    let id: String?
    let criteria: GmailFilterCriteria?
    let action: GmailFilterAction?
}

/// Gmail 过滤器条件
struct GmailFilterCriteria: Codable {
    let from: String?
    let to: String?
    let subject: String?
    let query: String?
    let negatedQuery: String?
    let hasAttachment: Bool?
    let excludeChats: Bool?
    let size: Int?
    let sizeComparison: String?
}

/// Gmail 过滤器动作
struct GmailFilterAction: Codable {
    let addLabelIds: [String]?
    let removeLabelIds: [String]?
    let forward: String?
}

/// Gmail 过滤器列表响应
struct GmailFiltersListResponse: Decodable {
    let filter: [GmailFilter]?
}

// MARK: - Token Refresh

/// OAuth 2.0 Token 刷新响应
struct TokenRefreshResponse: Decodable {
    let access_token: String
    let expires_in: Int?
    let token_type: String?
    let scope: String?
}
