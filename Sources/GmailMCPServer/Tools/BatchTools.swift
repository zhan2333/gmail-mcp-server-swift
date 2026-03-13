import Foundation
import FlooMCP

/// 批量操作工具 (2个)
public enum BatchTools {

    /// 获取所有批量操作工具
    public static func all(apiClient: GmailAPIClient) -> [SimpleTool] {
        [
            batchModifyTool(apiClient: apiClient),
            batchDeleteTool(apiClient: apiClient)
        ]
    }

    // MARK: - gmail_batch_modify_emails

    public static func batchModifyTool(apiClient: GmailAPIClient) -> SimpleTool {
        SimpleTool(
            sdkTool: Tool(
                name: "gmail_batch_modify_emails",
                description: "Modify labels on multiple messages at once. More efficient than modifying messages individually. Can add or remove labels from up to 1000 messages at a time.",
                inputSchema: objectSchema(
                    properties: [
                        "message_ids": arrayProperty(description: "Array of message IDs to modify (max 1000)", itemType: "string"),
                        "addLabelIds": arrayProperty(description: "Label IDs to add to all specified messages", itemType: "string"),
                        "removeLabelIds": arrayProperty(description: "Label IDs to remove from all specified messages", itemType: "string")
                    ],
                    required: ["message_ids"]
                )
            ),
            handler: { arguments in
                let extractor = ArgumentExtractor(arguments)
                let messageIds = try extractor.requiredStringArray("message_ids")

                guard !messageIds.isEmpty else {
                    throw GmailError.invalidArgument("message_ids", "At least one message ID is required")
                }

                var body: [String: Any] = ["ids": messageIds]
                if let addLabels = extractor.optionalStringArray("addLabelIds") {
                    body["addLabelIds"] = addLabels
                }
                if let removeLabels = extractor.optionalStringArray("removeLabelIds") {
                    body["removeLabelIds"] = removeLabels
                }

                let _ = try await apiClient.post(
                    path: "/users/me/messages/batchModify",
                    body: body
                )
                return "{\"success\": true, \"message\": \"Batch modify completed for \(messageIds.count) messages.\"}"
            }
        )
    }

    // MARK: - gmail_batch_delete_emails

    public static func batchDeleteTool(apiClient: GmailAPIClient) -> SimpleTool {
        SimpleTool(
            sdkTool: Tool(
                name: "gmail_batch_delete_emails",
                description: "Permanently delete multiple messages at once. This action cannot be undone. Maximum 1000 messages per request.",
                inputSchema: objectSchema(
                    properties: [
                        "message_ids": arrayProperty(description: "Array of message IDs to permanently delete (max 1000)", itemType: "string")
                    ],
                    required: ["message_ids"]
                )
            ),
            handler: { arguments in
                let extractor = ArgumentExtractor(arguments)
                let messageIds = try extractor.requiredStringArray("message_ids")

                guard !messageIds.isEmpty else {
                    throw GmailError.invalidArgument("message_ids", "At least one message ID is required")
                }

                let body: [String: Any] = ["ids": messageIds]

                let _ = try await apiClient.post(
                    path: "/users/me/messages/batchDelete",
                    body: body
                )
                return "{\"success\": true, \"message\": \"Batch delete completed for \(messageIds.count) messages.\"}"
            }
        )
    }
}
