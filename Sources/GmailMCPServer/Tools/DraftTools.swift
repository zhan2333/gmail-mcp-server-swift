import Foundation
import FlooMCP

/// 草稿工具 (1个)
public enum DraftTools {

    /// 获取所有草稿工具
    public static func all(apiClient: GmailAPIClient) -> [SimpleTool] {
        [
            draftEmailTool(apiClient: apiClient)
        ]
    }

    // MARK: - gmail_draft_email

    public static func draftEmailTool(apiClient: GmailAPIClient) -> SimpleTool {
        SimpleTool(
            sdkTool: Tool(
                name: "gmail_draft_email",
                description: "Create a draft email without sending it. The draft can be edited and sent later from the Gmail interface.",
                inputSchema: objectSchema(
                    properties: [
                        "to": arrayProperty(description: "Array of recipient email addresses", itemType: "string"),
                        "subject": stringProperty(description: "Email subject line"),
                        "body": stringProperty(description: "Plain text body of the email"),
                        "cc": arrayProperty(description: "Array of CC email addresses", itemType: "string"),
                        "bcc": arrayProperty(description: "Array of BCC email addresses", itemType: "string"),
                        "htmlBody": stringProperty(description: "HTML body of the email (optional)"),
                        "inReplyTo": stringProperty(description: "Message-ID to reply to (for threading)"),
                        "threadId": stringProperty(description: "Thread ID to associate this draft with")
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

                var message: [String: Any] = ["raw": raw]
                if let threadId = threadId {
                    message["threadId"] = threadId
                }

                let requestBody: [String: Any] = ["message": message]

                let data = try await apiClient.post(
                    path: "/users/me/drafts",
                    body: requestBody
                )
                return data.jsonString
            }
        )
    }
}
