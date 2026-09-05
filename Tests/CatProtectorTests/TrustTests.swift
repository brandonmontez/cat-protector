import XCTest

/// Cat Protector sees every keystroke on the machine. The only good reason to
/// trust software like that is being able to prove it does nothing with them.
/// This test fails the build if networking, process spawning, or file writing
/// ever creeps into the app's sources.
final class TrustTests: XCTestCase {
    private static let forbiddenAPIs = [
        "URLSession", "URLRequest", "NSURLConnection",
        "NWConnection", "NWListener", "NWBrowser",
        "CFSocket", "CFStream", "socket(", "connect(",
        "Process(", "NSTask", "posix_spawn", "system(",
        "FileHandle(forWritingAtPath", "FileHandle(forUpdatingAtPath",
        "write(to:", "write(toFile:", "createFile(",
        "NSPasteboard", "CGEventPost", ".post(tap:",
    ]

    private var sourcesDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // CatProtectorTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // repository root
            .appendingPathComponent("Sources/CatProtector")
    }

    func testAppSourcesNeverTalkToTheNetworkWriteFilesOrSpawnProcesses() throws {
        let files = try FileManager.default.contentsOfDirectory(at: sourcesDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
        XCTAssertGreaterThan(files.count, 5, "Expected to find the app's Swift sources at \(sourcesDirectory.path)")

        for file in files {
            let source = try String(contentsOf: file, encoding: .utf8)
            for api in Self.forbiddenAPIs where source.contains(api) {
                XCTFail("\(file.lastPathComponent) uses \(api). Cat Protector must never network, write files, or spawn processes.")
            }
        }
    }

    func testOnlyPreferencesArePersisted() throws {
        let settings = try String(contentsOf: sourcesDirectory.appendingPathComponent("Settings.swift"), encoding: .utf8)
        XCTAssertTrue(settings.contains("UserDefaults"), "Settings should live in UserDefaults and nowhere else")
    }
}
