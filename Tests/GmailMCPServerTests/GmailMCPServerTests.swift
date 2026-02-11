import XCTest
@testable import GmailMCPServer
import MCP

final class GmailMCPServerTests: XCTestCase {

    func testServerInitialization() async throws {
        let server = GmailMCPServer(accessToken: "test_token")

        XCTAssertEqual(server.name, "gmail")
        XCTAssertEqual(server.version, "1.0.0")
        XCTAssertFalse(server.isRunning)
    }

    func testServerLifecycle() async throws {
        let server = GmailMCPServer(accessToken: "test_token")

        XCTAssertFalse(server.isRunning)

        try await server.start()
        XCTAssertTrue(server.isRunning)

        await server.stop()
        XCTAssertFalse(server.isRunning)
    }

    func testToolRegistration() async throws {
        let server = GmailMCPServer(accessToken: "test_token")

        // 等待工具初始化
        try await Task.sleep(nanoseconds: 100_000_000)

        let tools = server.getTools()
        XCTAssertEqual(tools.count, 19, "Should have 19 tools registered")
    }

    func testAllExpectedToolNamesAreRegistered() async throws {
        let server = GmailMCPServer(accessToken: "test_token")

        // 等待工具初始化
        try await Task.sleep(nanoseconds: 100_000_000)

        let toolNames = server.getToolNames()
        let expectedTools = GmailTools.toolNames

        for expectedName in expectedTools {
            XCTAssertTrue(toolNames.contains(expectedName), "Missing tool: \(expectedName)")
        }
    }

    func testUnknownToolExecution() async throws {
        let server = GmailMCPServer(accessToken: "test_token")

        // 等待工具初始化
        try await Task.sleep(nanoseconds: 100_000_000)

        do {
            _ = try await server.executeTool(name: "unknown_tool", arguments: [:])
            XCTFail("Should throw error for unknown tool")
        } catch let error as GmailError {
            if case .toolNotFound(let name) = error {
                XCTAssertEqual(name, "unknown_tool")
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }
}

// MARK: - Config Tests

final class GmailConfigTests: XCTestCase {

    func testDefaultConfig() {
        let config = GmailConfig(accessToken: "test_token")

        XCTAssertEqual(config.accessToken, "test_token")
        XCTAssertNil(config.refreshToken)
        XCTAssertNil(config.clientId)
        XCTAssertNil(config.clientSecret)
        XCTAssertEqual(config.baseURL, GmailConfig.defaultBaseURL)
        XCTAssertEqual(config.timeout, GmailConfig.defaultTimeout)
        XCTAssertFalse(config.canRefreshToken)
    }

    func testFullConfig() {
        let config = GmailConfig(
            accessToken: "access",
            refreshToken: "refresh",
            clientId: "client_id",
            clientSecret: "client_secret"
        )

        XCTAssertEqual(config.accessToken, "access")
        XCTAssertEqual(config.refreshToken, "refresh")
        XCTAssertEqual(config.clientId, "client_id")
        XCTAssertEqual(config.clientSecret, "client_secret")
        XCTAssertTrue(config.canRefreshToken)
    }

    func testConfigValidation() {
        let validConfig = GmailConfig(accessToken: "test_token")
        XCTAssertNoThrow(try validConfig.validate())

        let invalidConfig = GmailConfig(accessToken: "")
        XCTAssertThrowsError(try invalidConfig.validate()) { error in
            XCTAssertTrue(error is GmailError)
        }
    }
}

// MARK: - Email Builder Tests

final class GmailEmailBuilderTests: XCTestCase {

    func testBase64urlEncode() {
        let input = "Hello, World!"
        let encoded = GmailEmailBuilder.base64urlEncode(input)
        // 标准 base64: "SGVsbG8sIFdvcmxkIQ=="
        // base64url:   "SGVsbG8sIFdvcmxkIQ"
        XCTAssertFalse(encoded.contains("+"))
        XCTAssertFalse(encoded.contains("/"))
        XCTAssertFalse(encoded.contains("="))
    }

    func testBuildRawPlainText() throws {
        let raw = try GmailEmailBuilder.buildRaw(
            to: ["test@example.com"],
            subject: "Test Subject",
            body: "Hello, this is a test."
        )
        XCTAssertFalse(raw.isEmpty)
        // raw 是 base64url 编码的
        XCTAssertFalse(raw.contains("="))
    }

    func testBuildRawWithHTML() throws {
        let raw = try GmailEmailBuilder.buildRaw(
            to: ["test@example.com"],
            subject: "Test Subject",
            body: "Plain text version",
            htmlBody: "<h1>HTML version</h1>"
        )
        XCTAssertFalse(raw.isEmpty)
    }

    func testBuildRawEmptyRecipient() {
        XCTAssertThrowsError(try GmailEmailBuilder.buildRaw(
            to: [],
            subject: "Test",
            body: "Test"
        )) { error in
            XCTAssertTrue(error is GmailError)
        }
    }

    func testBuildRawWithCcBcc() throws {
        let raw = try GmailEmailBuilder.buildRaw(
            to: ["to@example.com"],
            cc: ["cc@example.com"],
            bcc: ["bcc@example.com"],
            subject: "Test",
            body: "Test body"
        )
        XCTAssertFalse(raw.isEmpty)
    }

    func testEncodeNonASCIISubject() throws {
        let raw = try GmailEmailBuilder.buildRaw(
            to: ["test@example.com"],
            subject: "测试主题",
            body: "Test body"
        )
        XCTAssertFalse(raw.isEmpty)
    }
}

// MARK: - Argument Extractor Tests

final class ArgumentExtractorTests: XCTestCase {

    func testRequiredString() throws {
        let args: [String: Value] = [
            "name": .string("test")
        ]
        let extractor = ArgumentExtractor(args)

        let value = try extractor.requiredString("name")
        XCTAssertEqual(value, "test")
    }

    func testMissingRequiredString() {
        let args: [String: Value] = [:]
        let extractor = ArgumentExtractor(args)

        XCTAssertThrowsError(try extractor.requiredString("name")) { error in
            XCTAssertTrue(error is GmailError)
        }
    }

    func testOptionalString() {
        let args: [String: Value] = [
            "name": .string("test")
        ]
        let extractor = ArgumentExtractor(args)

        XCTAssertEqual(extractor.optionalString("name"), "test")
        XCTAssertNil(extractor.optionalString("missing"))
    }

    func testOptionalInt() {
        let args: [String: Value] = [
            "count": .int(42)
        ]
        let extractor = ArgumentExtractor(args)

        XCTAssertEqual(extractor.optionalInt("count"), 42)
        XCTAssertNil(extractor.optionalInt("missing"))
    }

    func testRequiredStringArray() throws {
        let args: [String: Value] = [
            "emails": .array([.string("a@b.com"), .string("c@d.com")])
        ]
        let extractor = ArgumentExtractor(args)

        let emails = try extractor.requiredStringArray("emails")
        XCTAssertEqual(emails, ["a@b.com", "c@d.com"])
    }

    func testOptionalStringArray() {
        let args: [String: Value] = [
            "tags": .array([.string("tag1"), .string("tag2")])
        ]
        let extractor = ArgumentExtractor(args)

        let tags = extractor.optionalStringArray("tags")
        XCTAssertEqual(tags, ["tag1", "tag2"])
        XCTAssertNil(extractor.optionalStringArray("missing"))
    }

    func testHas() {
        let args: [String: Value] = [
            "key": .string("value"),
            "nullKey": .null
        ]
        let extractor = ArgumentExtractor(args)

        XCTAssertTrue(extractor.has("key"))
        XCTAssertFalse(extractor.has("nullKey"))
        XCTAssertFalse(extractor.has("missing"))
    }
}

// MARK: - Value Extensions Tests

final class ValueExtensionsTests: XCTestCase {

    func testValueToAny() {
        let stringValue = Value.string("test")
        XCTAssertEqual(stringValue.toAny() as? String, "test")

        let intValue = Value.int(42)
        XCTAssertEqual(intValue.toAny() as? Int, 42)

        let boolValue = Value.bool(true)
        XCTAssertEqual(boolValue.toAny() as? Bool, true)

        let nullValue = Value.null
        XCTAssertNil(nullValue.toAny())
    }

    func testAnyToValue() {
        let stringValue = Value.from("test")
        XCTAssertEqual(stringValue.stringValue, "test")

        let intValue = Value.from(42)
        XCTAssertEqual(intValue.intValue, 42)

        let boolValue = Value.from(true)
        XCTAssertEqual(boolValue.boolValue, true)

        let nullValue = Value.from(nil)
        XCTAssertTrue(nullValue.isNull)
    }
}
