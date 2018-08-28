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
    override func setUp() {
        super.setUp()

        if let projectDir = ProcessInfo.processInfo.environment["PROJECT_DIR"] {
            FileManager.default.changeCurrentDirectoryPath(projectDir)
        }
    }

    override func tearDown() {
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

    func prepareFiles(srcSubPath: String, dstSubPath: String) throws {
        if let projectDir = ProcessInfo.processInfo.environment["PROJECT_DIR"] {
            let packPath = projectDir.appendingPathComponent("testing").appendingPathComponent(srcSubPath)
            let deskPath = "~/Desktop".expandingTildeInPath.appendingPathComponent(dstSubPath)

            try FileManager.default.copyItem(atPath: packPath, toPath: deskPath)
        } else {
            throw TestErrors.noProjectDir
        }
    }

    func cleanupFiles(dstSubPath: String) throws {
        let deskUrl = URL(fileURLWithPath: "~/Desktop".expandingTildeInPath.appendingPathComponent(dstSubPath))

        try FileManager.default.trashItem(at: deskUrl, resultingItemURL: nil)
    }

    func testManifest() {
        XCTAssertNoThrow(try prepareFiles(srcSubPath: "test.xcstickers/Sticker Pack.stickerpack", dstSubPath: "Sticker Pack.stickerpack"))
        var manifestPath: String?
        XCTAssertNoThrow(manifestPath = try testFilePath(srcSubPath: "manifest.txt"))
        let process = ProcessCommand()
        var cmd = ParsedCommand()

        cmd.toolName = "imp"
        cmd.subcommand = "process"
        if let manifestPath = manifestPath {
            cmd.parameters.append(manifestPath)
        }

        process.run(cmd: cmd)
        XCTAssertNoThrow(try cleanupFiles(dstSubPath: "Sticker Pack.stickerpack"))
    }

    func testClearStickerPack() {
        XCTAssertNoThrow(try prepareFiles(srcSubPath: "test.xcstickers/Sticker Pack.stickerpack", dstSubPath: "Sticker Pack.stickerpack"))
        let deskPath = "~/Desktop/Sticker Pack.stickerpack".expandingTildeInPath
        let process = ProcessCommand()
        process.clearStickerPack(folder: deskPath)
        XCTAssertNoThrow(try cleanupFiles(dstSubPath: "Sticker Pack.stickerpack"))
    }

    func testClearCatalog() {
        XCTAssertNoThrow(try prepareFiles(srcSubPath: "test2.xcassets", dstSubPath: "test2.xcassets"))
        let deskPath = "~/Desktop/test2.xcassets".expandingTildeInPath
        let process = ProcessCommand()
        process.clearCatalog(folder: deskPath)
        XCTAssertNoThrow(try cleanupFiles(dstSubPath: "test2.xcassets"))
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
