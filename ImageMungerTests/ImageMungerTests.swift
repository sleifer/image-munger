//
//  ImageMungerTests.swift
//  ImageMungerTests
//
//  Created by Simeon Leifer on 8/31/18.
//  Copyright © 2018 droolingcat.com. All rights reserved.
//

import XCTest
import CommandLineCore

enum TestErrors: Error {
    case noProjectDir
}

class ImageMungerTests: XCTestCase {
    static var deskPath: String = ""

    override class func setUp() {
        super.setUp()

        if let projectDir = ProcessInfo.processInfo.environment["PROJECT_DIR"] {
            FileManager.default.changeCurrentDirectoryPath(projectDir)
        }

        let fmt = DateFormatter()
        fmt.dateFormat = "YYYYMMdd.HHmmss"

        deskPath = "~/Desktop/" + fmt.string(from: Date())
        deskPath = deskPath.expandingTildeInPath
        do {
            try FileManager.default.createDirectory(atPath: deskPath, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("Error creating output directory: \(error)")
        }
    }

    fileprivate static func cleanup() {
        do {
            try cleanupFile(deskPath)
        } catch {
            print("Error cleaning up output directory: \(error)")
        }
    }

    override class func tearDown() {
//        cleanup()

        super.tearDown()
    }

    func testFilePath(srcSubPath: String) throws -> String {
        if let projectDir = ProcessInfo.processInfo.environment["PROJECT_DIR"] {
            let path = projectDir.appendingPathComponent("testing").appendingPathComponent(srcSubPath)

            return path
        } else {
            throw TestErrors.noProjectDir
        }
    }

    @discardableResult
    func prepareFiles(srcSubPath: String, dstSubPath: String) throws -> String {
        if let projectDir = ProcessInfo.processInfo.environment["PROJECT_DIR"] {
            let packPath = projectDir.appendingPathComponent("testing").appendingPathComponent(srcSubPath)
            let dstPath = ImageMungerTests.deskPath.appendingPathComponent(dstSubPath)

            try FileManager.default.copyItem(atPath: packPath, toPath: dstPath)

            return dstPath
        } else {
            throw TestErrors.noProjectDir
        }
    }

    @discardableResult
    func prepareDirectory(dstSubPath: String) throws -> String {
        let dstPath = ImageMungerTests.deskPath.appendingPathComponent(dstSubPath)

        try FileManager.default.createDirectory(atPath: dstPath, withIntermediateDirectories: true, attributes: nil)

        return dstPath
    }

    class func cleanupFile(_ path: String) throws {
        let url = URL(fileURLWithPath: path)
        try FileManager.default.trashItem(at: url, resultingItemURL: nil)
    }

    func testManifest() throws {
        try prepareFiles(srcSubPath: "test.xcstickers", dstSubPath: "smallSticker.xcstickers")
        try prepareFiles(srcSubPath: "test.xcstickers", dstSubPath: "mediumSticker.xcstickers")
        try prepareFiles(srcSubPath: "test.xcstickers", dstSubPath: "largeSticker.xcstickers")
        try prepareDirectory(dstSubPath: "thumb256")

        let manifestPath = try testFilePath(srcSubPath: "manifest.txt")
        let process = ProcessCommand()
        var cmd = ParsedCommand()
        cmd.toolName = "imp"
        cmd.subcommand = "process"
        cmd.parameters.append(manifestPath)
        var option = ParsedOption()
        option.longOption = "--output"
        option.arguments.append(ImageMungerTests.deskPath)
        cmd.options.append(option)

        process.run(cmd: cmd)
    }

    func testClearStickerPack() throws {
        let cleanPath = try prepareFiles(srcSubPath: "test.xcstickers", dstSubPath: "clearSticker.xcstickers")
        let process = ProcessCommand()
        process.clearStickerPack(folder: cleanPath.appendingPathComponent("Sticker Pack.stickerpack"))
    }

    func testClearCatalog() throws {
        let cleanPath = try prepareFiles(srcSubPath: "test2.xcassets", dstSubPath: "clearCatalog.xcassets")
        let process = ProcessCommand()
        process.clearCatalog(folder: cleanPath)
    }

    func testHasFileSuffix() {
        let s1 = "~/Desktop/foo@3x.png"
        let h1 = s1.hasFileSuffix("@2x")
        XCTAssertFalse(h1)
        let h2 = s1.hasFileSuffix("@3x")
        XCTAssertTrue(h2)
    }

    func testChangeFileSuffix() {
        let s1 = "~/Desktop/foo@3x.png"
        let s2 = s1.changeFileSuffix(from: "@3x", to: "@2x")
        XCTAssertEqual(s2, "~/Desktop/foo@2x.png")
        let s3 = s1.changeFileSuffix(from: "@3x", to: "")
        XCTAssertEqual(s3, "~/Desktop/foo.png")
        let s4 = s1.changeFileSuffix(from: "@2x", to: "@3x")
        XCTAssertEqual(s4, "~/Desktop/foo@3x.png")
    }

    func testChangeFileExtension() {
        let s1 = "~/Desktop/foo@3x.png"
        let s2 = s1.changeFileExtension(from: "png", to: "gif")
        XCTAssertEqual(s2, "~/Desktop/foo@3x.gif")
        let s3 = s1.changeFileExtension(from: "tif", to: "gif")
        XCTAssertEqual(s3, "~/Desktop/foo@3x.png")
   }
}
