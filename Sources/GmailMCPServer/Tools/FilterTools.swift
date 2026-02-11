import Foundation
import MCP

/// 过滤器工具 (5个)
public enum FilterTools {

    /// 获取所有过滤器工具
    public static func all(apiClient: GmailAPIClient) -> [SimpleTool] {
        [
            createFilterTool(apiClient: apiClient),
            listFiltersTool(apiClient: apiClient),
            getFilterTool(apiClient: apiClient),
            deleteFilterTool(apiClient: apiClient),
            createFilterFromTemplateTool(apiClient: apiClient)
        ]
    }

    // MARK: - gmail_create_filter

    public static func createFilterTool(apiClient: GmailAPIClient) -> SimpleTool {
        SimpleTool(
            sdkTool: Tool(
                name: "gmail_create_filter",
                description: "Create a new Gmail filter with specified criteria and actions. Filters automatically process incoming messages that match the criteria.",
                inputSchema: objectSchema(
                    properties: [
                        "criteria": .object([
                            "type": .string("object"),
                            "description": .string("Filter criteria to match messages"),
                            "properties": .object([
                                "from": stringProperty(description: "Sender email address to match"),
                                "to": stringProperty(description: "Recipient email address to match"),
                                "subject": stringProperty(description: "Subject text to match"),
                                "query": stringProperty(description: "Gmail search query to match"),
                                "negatedQuery": stringProperty(description: "Gmail search query to exclude"),
                                "hasAttachment": booleanProperty(description: "Match messages with attachments"),
                                "excludeChats": booleanProperty(description: "Exclude chat messages"),
                                "size": integerProperty(description: "Message size in bytes for comparison"),
                                "sizeComparison": enumProperty(description: "Size comparison operator", values: ["larger", "smaller"])
                            ])
                        ]),
                        "action": .object([
                            "type": .string("object"),
                            "description": .string("Actions to perform on matching messages"),
                            "properties": .object([
                                "addLabelIds": arrayProperty(description: "Label IDs to add", itemType: "string"),
                                "removeLabelIds": arrayProperty(description: "Label IDs to remove", itemType: "string"),
                                "forward": stringProperty(description: "Email address to forward to")
                            ])
                        ])
                    ],
                    required: ["criteria", "action"]
                )
            ),
            handler: { arguments in
                let extractor = ArgumentExtractor(arguments)
                let criteria = try extractor.requiredObject("criteria")
                let action = try extractor.requiredObject("action")

                let body: [String: Any] = [
                    "criteria": criteria.toAnyDict(),
                    "action": action.toAnyDict()
                ]

                let data = try await apiClient.post(
                    path: "/users/me/settings/filters",
                    body: body
                )
                return data.jsonString
            }
        )
    }

    // MARK: - gmail_list_filters

    public static func listFiltersTool(apiClient: GmailAPIClient) -> SimpleTool {
        SimpleTool(
            sdkTool: Tool(
                name: "gmail_list_filters",
                description: "List all Gmail filters configured for the account. Returns filter criteria and actions.",
                inputSchema: objectSchema(
                    properties: [:],
                    required: []
                )
            ),
            handler: { _ in
                let data = try await apiClient.get(path: "/users/me/settings/filters")
                return data.jsonString
            }
        )
    }

    // MARK: - gmail_get_filter

    public static func getFilterTool(apiClient: GmailAPIClient) -> SimpleTool {
        SimpleTool(
            sdkTool: Tool(
                name: "gmail_get_filter",
                description: "Get details of a specific Gmail filter by its ID.",
                inputSchema: objectSchema(
                    properties: [
                        "filter_id": stringProperty(description: "The ID of the filter to retrieve")
                    ],
                    required: ["filter_id"]
                )
            ),
            handler: { arguments in
                let extractor = ArgumentExtractor(arguments)
                let filterId = try extractor.requiredString("filter_id")

                let data = try await apiClient.get(path: "/users/me/settings/filters/\(filterId)")
                return data.jsonString
            }
        )
    }

    // MARK: - gmail_delete_filter

    public static func deleteFilterTool(apiClient: GmailAPIClient) -> SimpleTool {
        SimpleTool(
            sdkTool: Tool(
                name: "gmail_delete_filter",
                description: "Delete a Gmail filter by its ID.",
                inputSchema: objectSchema(
                    properties: [
                        "filter_id": stringProperty(description: "The ID of the filter to delete")
                    ],
                    required: ["filter_id"]
                )
            ),
            handler: { arguments in
                let extractor = ArgumentExtractor(arguments)
                let filterId = try extractor.requiredString("filter_id")

                let _ = try await apiClient.delete(path: "/users/me/settings/filters/\(filterId)")
                return "{\"success\": true, \"message\": \"Filter deleted successfully.\"}"
            }
        )
    }

    // MARK: - gmail_create_filter_from_template

    public static func createFilterFromTemplateTool(apiClient: GmailAPIClient) -> SimpleTool {
        SimpleTool(
            sdkTool: Tool(
                name: "gmail_create_filter_from_template",
                description: """
                    Create a filter from a predefined template. Available templates:
                    - fromSender: Filter emails from a specific sender
                    - withSubject: Filter emails with specific subject text
                    - withAttachments: Filter emails that have attachments
                    - largeEmails: Filter emails larger than a specified size
                    - containingText: Filter emails containing specific text
                    - mailingList: Filter mailing list emails
                    """,
                inputSchema: objectSchema(
                    properties: [
                        "template": enumProperty(
                            description: "The template to use",
                            values: ["fromSender", "withSubject", "withAttachments", "largeEmails", "containingText", "mailingList"]
                        ),
                        "value": stringProperty(description: "The primary value for the template (email for fromSender, text for withSubject/containingText, list identifier for mailingList)"),
                        "sizeInBytes": integerProperty(description: "Size threshold in bytes (required for largeEmails template)"),
                        "labelIds": arrayProperty(description: "Label IDs to apply to matching messages", itemType: "string"),
                        "archive": booleanProperty(description: "Whether to archive matching messages (remove from INBOX)"),
                        "markAsRead": booleanProperty(description: "Whether to mark matching messages as read (remove UNREAD label)")
                    ],
                    required: ["template"]
                )
            ),
            handler: { arguments in
                let extractor = ArgumentExtractor(arguments)
                let template = try extractor.requiredString("template")
                let value = extractor.optionalString("value")
                let sizeInBytes = extractor.optionalInt("sizeInBytes")
                let labelIds = extractor.optionalStringArray("labelIds") ?? []
                let archive = extractor.optionalBool("archive") ?? false
                let markAsRead = extractor.optionalBool("markAsRead") ?? false

                var criteria: [String: Any] = [:]
                var action: [String: Any] = [:]

                switch template {
                case "fromSender":
                    guard let sender = value else {
                        throw GmailError.missingRequiredArgument("value (sender email)")
                    }
                    criteria["from"] = sender
                    if !labelIds.isEmpty { action["addLabelIds"] = labelIds }
                    if archive { action["removeLabelIds"] = ["INBOX"] }

                case "withSubject":
                    guard let subject = value else {
                        throw GmailError.missingRequiredArgument("value (subject text)")
                    }
                    criteria["subject"] = subject
                    if !labelIds.isEmpty { action["addLabelIds"] = labelIds }
                    if markAsRead { action["removeLabelIds"] = ["UNREAD"] }

                case "withAttachments":
                    criteria["hasAttachment"] = true
                    if !labelIds.isEmpty { action["addLabelIds"] = labelIds }

                case "largeEmails":
                    guard let size = sizeInBytes else {
                        throw GmailError.missingRequiredArgument("sizeInBytes")
                    }
                    criteria["size"] = size
                    criteria["sizeComparison"] = "larger"
                    if !labelIds.isEmpty { action["addLabelIds"] = labelIds }

                case "containingText":
                    guard let text = value else {
                        throw GmailError.missingRequiredArgument("value (search text)")
                    }
                    criteria["query"] = "\"\(text)\""
                    if !labelIds.isEmpty { action["addLabelIds"] = labelIds }

                case "mailingList":
                    guard let listId = value else {
                        throw GmailError.missingRequiredArgument("value (list identifier)")
                    }
                    criteria["query"] = "list:\(listId) OR subject:[\(listId)]"
                    if !labelIds.isEmpty { action["addLabelIds"] = labelIds }
                    if archive { action["removeLabelIds"] = ["INBOX"] }

                default:
                    throw GmailError.invalidArgument("template", "Unknown template: \(template)")
                }

                let body: [String: Any] = [
                    "criteria": criteria,
                    "action": action
                ]

                let data = try await apiClient.post(
                    path: "/users/me/settings/filters",
                    body: body
                )
                return data.jsonString
            }
        )
    }
}
