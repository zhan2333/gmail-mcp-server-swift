import Foundation

/// RFC 2822 邮件构造器 + base64url 编码
public enum GmailEmailBuilder {

    /// 构建 RFC 2822 格式邮件
    /// - Parameters:
    ///   - to: 收件人列表
    ///   - cc: 抄送列表
    ///   - bcc: 密送列表
    ///   - subject: 邮件主题
    ///   - body: 纯文本正文
    ///   - htmlBody: HTML 正文
    ///   - inReplyTo: 回复的 Message-ID
    /// - Returns: base64url 编码的邮件字符串
    public static func buildRaw(
        to: [String],
        cc: [String]? = nil,
        bcc: [String]? = nil,
        subject: String,
        body: String,
        htmlBody: String? = nil,
        inReplyTo: String? = nil
    ) throws -> String {
        let rfc2822 = try buildRFC2822(
            to: to, cc: cc, bcc: bcc,
            subject: subject, body: body,
            htmlBody: htmlBody, inReplyTo: inReplyTo
        )
        return base64urlEncode(rfc2822)
    }

    /// 构建 RFC 2822 格式邮件字符串
    static func buildRFC2822(
        to: [String],
        cc: [String]? = nil,
        bcc: [String]? = nil,
        subject: String,
        body: String,
        htmlBody: String? = nil,
        inReplyTo: String? = nil
    ) throws -> String {
        guard !to.isEmpty else {
            throw GmailError.emailConstructionFailed("At least one recipient is required")
        }

        let encodedSubject = encodeEmailHeader(subject)
        let boundary = "----=_NextPart_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"

        var parts: [String] = []

        // Headers
        parts.append("From: me")
        parts.append("To: \(to.joined(separator: ", "))")
        if let cc = cc, !cc.isEmpty {
            parts.append("Cc: \(cc.joined(separator: ", "))")
        }
        if let bcc = bcc, !bcc.isEmpty {
            parts.append("Bcc: \(bcc.joined(separator: ", "))")
        }
        parts.append("Subject: \(encodedSubject)")
        if let inReplyTo = inReplyTo {
            parts.append("In-Reply-To: \(inReplyTo)")
            parts.append("References: \(inReplyTo)")
        }
        parts.append("MIME-Version: 1.0")

        // Body
        if let htmlBody = htmlBody {
            // multipart/alternative
            parts.append("Content-Type: multipart/alternative; boundary=\"\(boundary)\"")
            parts.append("")

            // Plain text part
            parts.append("--\(boundary)")
            parts.append("Content-Type: text/plain; charset=\"UTF-8\"")
            parts.append("Content-Transfer-Encoding: 7bit")
            parts.append("")
            parts.append(body)
            parts.append("")

            // HTML part
            parts.append("--\(boundary)")
            parts.append("Content-Type: text/html; charset=\"UTF-8\"")
            parts.append("Content-Transfer-Encoding: 7bit")
            parts.append("")
            parts.append(htmlBody)
            parts.append("")

            // Close boundary
            parts.append("--\(boundary)--")
        } else {
            // Plain text only
            parts.append("Content-Type: text/plain; charset=\"UTF-8\"")
            parts.append("Content-Transfer-Encoding: 7bit")
            parts.append("")
            parts.append(body)
        }

        return parts.joined(separator: "\r\n")
    }

    /// RFC 2047 MIME 编码邮件头（非 ASCII 字符）
    static func encodeEmailHeader(_ text: String) -> String {
        let hasNonASCII = text.unicodeScalars.contains { $0.value > 127 }
        if hasNonASCII {
            let base64 = Data(text.utf8).base64EncodedString()
            return "=?UTF-8?B?\(base64)?="
        }
        return text
    }

    /// Base64url 编码（Gmail API 要求）
    /// 标准 base64 → `+`→`-`, `/`→`_`, 去掉 `=`
    public static func base64urlEncode(_ string: String) -> String {
        let data = Data(string.utf8)
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
