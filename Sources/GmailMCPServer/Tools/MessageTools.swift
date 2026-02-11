import Foundation
import MCP

/// 邮件工具 (6个)
public enum MessageTools {

    /// 获取所有邮件工具
    public static func all(apiClient: GmailAPIClient) -> [SimpleTool] {
        [
            sendEmailTool(apiClient: apiClient),
            readEmailTool(apiClient: apiClient),
            searchEmailsTool(apiClient: apiClient),
            modifyEmailTool(apiClient: apiClient),
            deleteEmailTool(apiClient: apiClient),
            downloadAttachmentTool(apiClient: apiClient)
        ]
    }

    // MARK: - gmail_send_email

    public static func sendEmailTool(apiClient: GmailAPIClient) -> SimpleTool {
        SimpleTool(
            sdkTool: Tool(
                name: "gmail_send_email",
                description: "Send an email through Gmail. Supports plain text, HTML, CC, BCC, and reply-to functionality.",
                inputSchema: objectSchema(
                    properties: [
                        "to": arrayProperty(description: "Array of recipient email addresses", itemType: "string"),
                        "subject": stringProperty(description: "Email subject line"),
                        "body": stringProperty(description: "Plain text body of the email"),
                        "cc": arrayProperty(description: "Array of CC email addresses", itemType: "string"),
                        "bcc": arrayProperty(description: "Array of BCC email addresses", itemType: "string"),
                        "htmlBody": stringProperty(description: "HTML body of the email (optional, will create multipart message)"),
                        "inReplyTo": stringProperty(description: "Message-ID to reply to (for threading)"),
                        "threadId": stringProperty(description: "Thread ID to add this message to")
                    ],
                    required: ["to", "subject", "body"]
                )
            ),
            handler: { arguments in
                let extractor = ArgumentExtractor(arguments)
                let to = try extractor.requiredStringArray("to")
                let subject = try extractor.requiredString("subject")
                let body = try extractor.requiredString("body")
                let cc = extractor.optionalStringArray("cc")
                let bcc = extractor.optionalStringArray("bcc")
                let htmlBody = extractor.optionalString("htmlBody")
                let inReplyTo = extractor.optionalString("inReplyTo")
                let threadId = extractor.optionalString("threadId")

                let raw = try GmailEmailBuilder.buildRaw(
                    to: to, cc: cc, bcc: bcc,
                    subject: subject, body: body,
                    htmlBody: htmlBody, inReplyTo: inReplyTo
                )

                var requestBody: [String: Any] = ["raw": raw]
                if let threadId = threadId {
                    requestBody["threadId"] = threadId
                }

                let data = try await apiClient.post(
                    path: "/users/me/messages/send",
                    body: requestBody
                )
                return data.jsonString
            }
        )
    }

    // MARK: - gmail_read_email

    public static func readEmailTool(apiClient: GmailAPIClient) -> SimpleTool {
        SimpleTool(
            sdkTool: Tool(
                name: "gmail_read_email",
                description: "Read a specific email by its message ID. Returns full message content including headers, body, and attachment info.",
                inputSchema: objectSchema(
                    properties: [
                        "message_id": stringProperty(description: "The ID of the message to read"),
                        "format": enumProperty(
                            description: "The format to return the message in",
                            values: ["full", "metadata", "minimal", "raw"]
                        )
                    ],
                    required: ["message_id"]
                )
            ),
            handler: { arguments in
                let extractor = ArgumentExtractor(arguments)
                let messageId = try extractor.requiredString("message_id")
                let format = extractor.optionalString("format") ?? "full"

                let data = try await apiClient.get(
                    path: "/users/me/messages/\(messageId)",
                    queryParams: ["format": format]
                )

                // 解析并提取可读内容
                guard let jsonData = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    return data.jsonString
                }

                var result = jsonData
                // 尝试提取 body 内容
                if let payload = jsonData["payload"] as? [String: Any] {
                    if let bodyContent = extractBody(from: payload) {
                        result["extractedBody"] = bodyContent
                    }
                }

                let resultData = try JSONSerialization.data(withJSONObject: result)
                return String(data: resultData, encoding: .utf8) ?? data.jsonString
            }
        )
    }

    // MARK: - gmail_search_emails

    public static func searchEmailsTool(apiClient: GmailAPIClient) -> SimpleTool {
        SimpleTool(
            sdkTool: Tool(
                name: "gmail_search_emails",
                description: "Search for emails using Gmail's search syntax. Supports the same queries as the Gmail search box (e.g., 'from:user@example.com', 'subject:meeting', 'has:attachment', 'newer_than:2d').",
                inputSchema: objectSchema(
                    properties: [
                        "query": stringProperty(description: "Gmail search query string (same syntax as Gmail search box)"),
                        "maxResults": integerProperty(description: "Maximum number of results to return (default: 10, max: 500)"),
                        "pageToken": stringProperty(description: "Page token for pagination"),
                        "labelIds": arrayProperty(description: "Only return messages with these label IDs", itemType: "string")
                    ],
                    required: ["query"]
                )
            ),
            handler: { arguments in
                let extractor = ArgumentExtractor(arguments)
                let query = try extractor.requiredString("query")
                let maxResults = extractor.optionalInt("maxResults") ?? 10
                let pageToken = extractor.optionalString("pageToken")

                var queryParams: [String: String] = [
                    "q": query,
                    "maxResults": String(maxResults)
                ]
                if let pageToken = pageToken {
                    queryParams["pageToken"] = pageToken
                }
                if let labelIds = extractor.optionalStringArray("labelIds") {
                    queryParams["labelIds"] = labelIds.joined(separator: ",")
                }

                // 搜索获取消息 ID 列表
                let listData = try await apiClient.get(
                    path: "/users/me/messages",
                    queryParams: queryParams
                )

                guard let listJSON = try? JSONSerialization.jsonObject(with: listData) as? [String: Any],
                      let messages = listJSON["messages"] as? [[String: Any]] else {
                    return "{\"messages\": [], \"resultSizeEstimate\": 0}"
                }

                // 获取每条消息的元数据
                var results: [[String: Any]] = []
                for message in messages {
                    guard let id = message["id"] as? String else { continue }
                    let msgData = try await apiClient.get(
                        path: "/users/me/messages/\(id)",
                        queryParams: ["format": "metadata", "metadataHeaders": "From,To,Subject,Date"]
                    )
                    if let msgJSON = try? JSONSerialization.jsonObject(with: msgData) as? [String: Any] {
                        results.append(msgJSON)
                    }
                }

                let response: [String: Any] = [
                    "messages": results,
                    "resultSizeEstimate": listJSON["resultSizeEstimate"] ?? results.count,
                    "nextPageToken": listJSON["nextPageToken"] as Any
                ]
                let responseData = try JSONSerialization.data(withJSONObject: response)
                return String(data: responseData, encoding: .utf8) ?? "[]"
            }
        )
    }

    // MARK: - gmail_modify_email

    public static func modifyEmailTool(apiClient: GmailAPIClient) -> SimpleTool {
        SimpleTool(
            sdkTool: Tool(
                name: "gmail_modify_email",
                description: "Modify a message's labels. Can add or remove labels (e.g., mark as read by removing 'UNREAD', archive by removing 'INBOX', star by adding 'STARRED').",
                inputSchema: objectSchema(
                    properties: [
                        "message_id": stringProperty(description: "The ID of the message to modify"),
                        "addLabelIds": arrayProperty(description: "Label IDs to add to the message", itemType: "string"),
                        "removeLabelIds": arrayProperty(description: "Label IDs to remove from the message", itemType: "string")
                    ],
                    required: ["message_id"]
                )
            ),
            handler: { arguments in
                let extractor = ArgumentExtractor(arguments)
                let messageId = try extractor.requiredString("message_id")

                var body: [String: Any] = [:]
                if let addLabels = extractor.optionalStringArray("addLabelIds") {
                    body["addLabelIds"] = addLabels
                }
                if let removeLabels = extractor.optionalStringArray("removeLabelIds") {
                    body["removeLabelIds"] = removeLabels
                }

                let data = try await apiClient.post(
                    path: "/users/me/messages/\(messageId)/modify",
                    body: body
                )
                return data.jsonString
            }
        )
    }

    // MARK: - gmail_delete_email

    public static func deleteEmailTool(apiClient: GmailAPIClient) -> SimpleTool {
        SimpleTool(
            sdkTool: Tool(
                name: "gmail_delete_email",
                description: "Permanently delete an email message. This action cannot be undone. To move to trash instead, use gmail_modify_email to add the 'TRASH' label.",
                inputSchema: objectSchema(
                    properties: [
                        "message_id": stringProperty(description: "The ID of the message to permanently delete")
                    ],
                    required: ["message_id"]
                )
            ),
            handler: { arguments in
                let extractor = ArgumentExtractor(arguments)
                let messageId = try extractor.requiredString("message_id")

                let _ = try await apiClient.delete(path: "/users/me/messages/\(messageId)")
                return "{\"success\": true, \"message\": \"Email permanently deleted.\"}"
            }
        )
    }

    // MARK: - gmail_download_attachment

    public static func downloadAttachmentTool(apiClient: GmailAPIClient) -> SimpleTool {
        SimpleTool(
            sdkTool: Tool(
                name: "gmail_download_attachment",
                description: "Download an attachment from a specific email message. Returns the attachment data as base64 encoded string.",
                inputSchema: objectSchema(
                    properties: [
                        "message_id": stringProperty(description: "The ID of the message containing the attachment"),
                        "attachment_id": stringProperty(description: "The ID of the attachment to download")
                    ],
                    required: ["message_id", "attachment_id"]
                )
            ),
            handler: { arguments in
                let extractor = ArgumentExtractor(arguments)
                let messageId = try extractor.requiredString("message_id")
                let attachmentId = try extractor.requiredString("attachment_id")

                let data = try await apiClient.get(
                    path: "/users/me/messages/\(messageId)/attachments/\(attachmentId)"
                )
                return data.jsonString
            }
        )
    }

    // MARK: - Helper

    /// 递归提取邮件正文
    private static func extractBody(from payload: [String: Any]) -> String? {
        // 直接从 body 提取
        if let body = payload["body"] as? [String: Any],
           let data = body["data"] as? String,
           let decoded = base64urlDecode(data) {
            return decoded
        }

        // 从 parts 递归提取
        if let parts = payload["parts"] as? [[String: Any]] {
            for part in parts {
                let mimeType = part["mimeType"] as? String ?? ""
                if mimeType == "text/plain" || mimeType == "text/html" {
                    if let body = part["body"] as? [String: Any],
                       let data = body["data"] as? String,
                       let decoded = base64urlDecode(data) {
                        return decoded
                    }
                }
                // 递归处理嵌套 parts
                if let nested = extractBody(from: part) {
                    return nested
                }
            }
        }
        return nil
    }

    /// Base64url 解码
    private static func base64urlDecode(_ string: String) -> String? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        // 补齐 padding
        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }
        guard let data = Data(base64Encoded: base64) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
