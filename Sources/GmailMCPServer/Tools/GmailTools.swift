import Foundation
import FlooMCP

/// Gmail 工具集合入口
public enum GmailTools {

    /// 获取所有工具 (19个)
    public static func all(apiClient: GmailAPIClient) -> [SimpleTool] {
        var tools: [SimpleTool] = []

        // 标签工具 (5个)
        tools.append(contentsOf: LabelTools.all(apiClient: apiClient))

        // 邮件工具 (6个)
        tools.append(contentsOf: MessageTools.all(apiClient: apiClient))

        // 草稿工具 (1个)
        tools.append(contentsOf: DraftTools.all(apiClient: apiClient))

        // 过滤器工具 (5个)
        tools.append(contentsOf: FilterTools.all(apiClient: apiClient))

        // 批量操作工具 (2个)
        tools.append(contentsOf: BatchTools.all(apiClient: apiClient))

        return tools
    }

    /// 获取工具数量统计
    public static var toolCounts: [String: Int] {
        [
            "label": 5,
            "message": 6,
            "draft": 1,
            "filter": 5,
            "batch": 2,
            "total": 19
        ]
    }

    /// 获取所有工具名称
    public static var toolNames: [String] {
        [
            // 标签
            "gmail_list_labels",
            "gmail_create_label",
            "gmail_update_label",
            "gmail_delete_label",
            "gmail_get_or_create_label",
            // 邮件
            "gmail_send_email",
            "gmail_read_email",
            "gmail_search_emails",
            "gmail_modify_email",
            "gmail_delete_email",
            "gmail_download_attachment",
            // 草稿
            "gmail_draft_email",
            // 过滤器
            "gmail_create_filter",
            "gmail_list_filters",
            "gmail_get_filter",
            "gmail_delete_filter",
            "gmail_create_filter_from_template",
            // 批量操作
            "gmail_batch_modify_emails",
            "gmail_batch_delete_emails"
        ]
    }
}
