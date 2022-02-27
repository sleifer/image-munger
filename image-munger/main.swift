//
//  main.swift
//  image-munger
//
//  Created by Simeon Leifer on 8/24/18.
//  Copyright © 2018 droolingcat.com. All rights reserved.
//

import ArgumentParser
import CommandLineCore
import Foundation

struct Imp: ParsableCommand {
    static var configuration = CommandConfiguration(
        abstract: "A command-line tool to help automate image processing for projects",
        version: "imp version \(VersionStrings.fullVersion)",
        subcommands: [Imp.Process.self, Sample.self],
        defaultSubcommand: Process.self)
}

extension Imp {
    struct Process: ParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Process images according to manifest file.")

        @Option(name: .customLong("output"), help: "Output directory.", completion: .directory)
        var outputDirPath: String?

        @Argument(help: "Manifest file(s).", completion: .file(extensions: ["yml"]))
        var inputPaths: [String]

        mutating func run() {
            ProcessCommand().run(inputPaths: inputPaths, outputDirPath: outputDirPath)
        }
    }

    struct Sample: ParsableCommand {
        static var configuration = CommandConfiguration(
            abstract: "Write out a manifest file.")

        @Argument(help: "Output file path.", completion: .file(extensions: ["yml"]))
        var outputPath: String

        mutating func run() {
            print("ran Sample")
        }
    }
}

var cwd = WorkingDirectoryHelper()

func main() {
    #if DEBUG
    // for testing in Xcode
    cwd.setBaseDir("~/Documents/Code/GlowTools")
    #endif

    #if DEBUG
    // for testing in Xcode
    #if true
    Imp.main("Assets/imp.yml".components(separatedBy: "|"))
    #else
    do {
        let result = try Imp.parseAsRoot("imp|Assets/imp.yml".components(separatedBy: "|"))
        print(result)
    } catch {
        print(error)
    }
    #endif
    #else
    Imp.main()
    #endif
}

main()
