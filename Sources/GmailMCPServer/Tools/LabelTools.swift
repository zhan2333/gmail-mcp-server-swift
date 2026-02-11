import Foundation
import MCP

/// 标签工具 (5个)
public enum LabelTools {

    /// 获取所有标签工具
    public static func all(apiClient: GmailAPIClient) -> [SimpleTool] {
        [
            listLabelsTool(apiClient: apiClient),
            createLabelTool(apiClient: apiClient),
            updateLabelTool(apiClient: apiClient),
            deleteLabelTool(apiClient: apiClient),
            getOrCreateLabelTool(apiClient: apiClient)
        ]
    }

    // MARK: - gmail_list_labels

    public static func listLabelsTool(apiClient: GmailAPIClient) -> SimpleTool {
        SimpleTool(
            sdkTool: Tool(
                name: "gmail_list_labels",
                description: "List all Gmail labels including system labels and user-created labels. Returns label names, IDs, types, and message counts.",
                inputSchema: objectSchema(
                    properties: [:],
                    required: []
                )
            ),
            handler: { _ in
                let data = try await apiClient.get(path: "/users/me/labels")
                return data.jsonString
            }
        )
    }

    // MARK: - gmail_create_label

    public static func createLabelTool(apiClient: GmailAPIClient) -> SimpleTool {
        SimpleTool(
            sdkTool: Tool(
                name: "gmail_create_label",
                description: "Create a new Gmail label with optional visibility settings.",
                inputSchema: objectSchema(
                    properties: [
                        "name": stringProperty(description: "The name of the label to create"),
                        "messageListVisibility": enumProperty(
                            description: "Visibility of messages with this label in the message list",
                            values: ["show", "hide"]
                        ),
                        "labelListVisibility": enumProperty(
                            description: "Visibility of the label in the label list",
                            values: ["labelShow", "labelShowIfUnread", "labelHide"]
                        )
                    ],
                    required: ["name"]
                )
            ),
            handler: { arguments in
                let extractor = ArgumentExtractor(arguments)
                let name = try extractor.requiredString("name")

                var body: [String: Any] = ["name": name]
                if let messageListVisibility = extractor.optionalString("messageListVisibility") {
                    body["messageListVisibility"] = messageListVisibility
                }
                if let labelListVisibility = extractor.optionalString("labelListVisibility") {
                    body["labelListVisibility"] = labelListVisibility
                }

                let data = try await apiClient.post(path: "/users/me/labels", body: body)
                return data.jsonString
            }
        )
    }

    // MARK: - gmail_update_label

    public static func updateLabelTool(apiClient: GmailAPIClient) -> SimpleTool {
        SimpleTool(
            sdkTool: Tool(
                name: "gmail_update_label",
                description: "Update an existing Gmail label's name or visibility settings.",
                inputSchema: objectSchema(
                    properties: [
                        "label_id": stringProperty(description: "The ID of the label to update"),
                        "name": stringProperty(description: "New name for the label"),
                        "messageListVisibility": enumProperty(
                            description: "Visibility of messages with this label in the message list",
                            values: ["show", "hide"]
                        ),
                        "labelListVisibility": enumProperty(
                            description: "Visibility of the label in the label list",
                            values: ["labelShow", "labelShowIfUnread", "labelHide"]
                        )
                    ],
                    required: ["label_id"]
                )
            ),
            handler: { arguments in
                let extractor = ArgumentExtractor(arguments)
                let labelId = try extractor.requiredString("label_id")

                var body: [String: Any] = [:]
                if let name = extractor.optionalString("name") {
                    body["name"] = name
                }
                if let messageListVisibility = extractor.optionalString("messageListVisibility") {
                    body["messageListVisibility"] = messageListVisibility
                }
                if let labelListVisibility = extractor.optionalString("labelListVisibility") {
                    body["labelListVisibility"] = labelListVisibility
                }

                guard !body.isEmpty else {
                    throw GmailError.invalidArgument("updates", "At least one property must be provided to update")
                }

                let data = try await apiClient.patch(path: "/users/me/labels/\(labelId)", body: body)
                return data.jsonString
            }
        )
    }

    // MARK: - gmail_delete_label

    public static func deleteLabelTool(apiClient: GmailAPIClient) -> SimpleTool {
        SimpleTool(
            sdkTool: Tool(
                name: "gmail_delete_label",
                description: "Delete a Gmail label by its ID. System labels cannot be deleted.",
                inputSchema: objectSchema(
                    properties: [
                        "label_id": stringProperty(description: "The ID of the label to delete")
                    ],
                    required: ["label_id"]
                )
            ),
            handler: { arguments in
                let extractor = ArgumentExtractor(arguments)
                let labelId = try extractor.requiredString("label_id")

                let _ = try await apiClient.delete(path: "/users/me/labels/\(labelId)")
                return "{\"success\": true, \"message\": \"Label deleted successfully.\"}"
            }
        )
    }

    // MARK: - gmail_get_or_create_label

    public static func getOrCreateLabelTool(apiClient: GmailAPIClient) -> SimpleTool {
        SimpleTool(
            sdkTool: Tool(
                name: "gmail_get_or_create_label",
                description: "Get an existing label by name or create it if it doesn't exist. Useful for ensuring a label exists before applying it to messages.",
                inputSchema: objectSchema(
                    properties: [
                        "name": stringProperty(description: "The name of the label to find or create")
                    ],
                    required: ["name"]
                )
            ),
            handler: { arguments in
                let extractor = ArgumentExtractor(arguments)
                let name = try extractor.requiredString("name")

                // 先列出所有标签，查找是否已存在
                let listData = try await apiClient.get(path: "/users/me/labels")
                let listJSON = listData.jsonString

                // 解析查找
                if let jsonData = listJSON.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   let labels = json["labels"] as? [[String: Any]] {
                    for label in labels {
                        if let labelName = label["name"] as? String,
                           labelName.lowercased() == name.lowercased() {
                            let resultData = try JSONSerialization.data(withJSONObject: label)
                            return String(data: resultData, encoding: .utf8) ?? "{}"
                        }
                    }
                }

                // 不存在，创建新标签
                let body: [String: Any] = [
                    "name": name,
                    "messageListVisibility": "show",
                    "labelListVisibility": "labelShow"
                ]
                let data = try await apiClient.post(path: "/users/me/labels", body: body)
                return data.jsonString
            }
        )
    }
}
