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

    class func git(_ args: [String]) {
        FileManager.default.changeCurrentDirectoryPath(deskPath)
        ProcessRunner.runCommand("git", args: args)
    }

    func gitCommit(_ msg: String) {
        ImageMungerTests.git(["add", "-A"])
        ImageMungerTests.git(["commit", "-m", msg])
    }

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

        git(["init"])
        git(["config", "--local", "precommit.testemail", "false"])
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

    func testManifest01_smallSticker() throws {
        try prepareFiles(srcSubPath: "test.xcstickers", dstSubPath: "smallSticker.xcstickers")
        gitCommit("testManifest01_smallSticker prepare")

        let manifestPath = try testFilePath(srcSubPath: "smallSticker-manifest.txt")
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
        gitCommit("testManifest01_smallSticker finished")
    }

    func testManifest02_mediumSticker() throws {
        try prepareFiles(srcSubPath: "test.xcstickers", dstSubPath: "mediumSticker.xcstickers")
        gitCommit("testManifest02_mediumSticker prepare")

        let manifestPath = try testFilePath(srcSubPath: "mediumSticker-manifest.txt")
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
        gitCommit("testManifest02_mediumSticker finished")
    }

    func testManifest03_largeSticker() throws {
        try prepareFiles(srcSubPath: "test.xcstickers", dstSubPath: "largeSticker.xcstickers")
        gitCommit("testManifest03_largeSticker prepare")

        let manifestPath = try testFilePath(srcSubPath: "largeSticker-manifest.txt")
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
        gitCommit("testManifest03_largeSticker finished")
    }

    func testManifest04_thumb256() throws {
        try prepareDirectory(dstSubPath: "thumb256")
        gitCommit("testManifest04_thumb256 prepare")

        let manifestPath = try testFilePath(srcSubPath: "thumb256-manifest.txt")
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
        gitCommit("testManifest04_thumb256 finished")
    }

    func testManifest05_iconSet_app() throws {
        try prepareFiles(srcSubPath: "test.xcassets", dstSubPath: "iconset.xcassets")
        gitCommit("testManifest05_iconSet_app prepare")

        let manifestPath = try testFilePath(srcSubPath: "iconSet-app-manifest.txt")
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
        gitCommit("testManifest05_iconSet_app finished")
    }

    func testManifest06_iconSet_messages() throws {
        try prepareFiles(srcSubPath: "test.xcstickers", dstSubPath: "iconset.xcstickers")
        gitCommit("testManifest06_iconSet_messages prepare")

        let manifestPath = try testFilePath(srcSubPath: "iconSet-messages-manifest.txt")
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
        gitCommit("testManifest06_iconSet_messages finished")
    }

    func testManifest07_icns() throws {
        let manifestPath = try testFilePath(srcSubPath: "icns-manifest.txt")
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
        gitCommit("testManifest07_icns finished")
    }

    func testManifest08_imageSet() throws {
        try prepareFiles(srcSubPath: "test2.xcassets", dstSubPath: "imageset.xcassets")
        gitCommit("testManifest08_imageSet prepare")

        let manifestPath = try testFilePath(srcSubPath: "imageSet-manifest.txt")
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
        gitCommit("testManifest08_imageSet finished")
    }

    func testManifest09_imageSetForLargeSticker() throws {
        try prepareFiles(srcSubPath: "test2.xcassets", dstSubPath: "imageSetForLargeSticker.xcassets")
        gitCommit("testManifest09_imageSetForLargeSticker prepare")

        let manifestPath = try testFilePath(srcSubPath: "imageSetForLargeSticker-manifest.txt")
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
        gitCommit("testManifest09_imageSetForLargeSticker finished")
    }

    func testManifest10_imageFileForLargeSticker() throws {
        try prepareDirectory(dstSubPath: "stickerFiles")
        gitCommit("testManifest10_imageFileForLargeSticker prepare")

        let manifestPath = try testFilePath(srcSubPath: "imageFileForLargeSticker-manifest.txt")
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
        gitCommit("testManifest10_imageFileForLargeSticker finished")
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
