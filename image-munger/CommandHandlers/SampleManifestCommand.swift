//
//  SampleManifestCommand.swift
//  image-munger
//
//  Created by Simeon Leifer on 8/25/18.
//  Copyright © 2018 droolingcat.com. All rights reserved.
//

import AppKit
import CommandLineCore
import Foundation

class SampleManifestCommand: Command {
    var manifest: Manifest = Manifest()
    var catalogFolderSegmentMaxSize: Int = 0
    var catalogFolderSegmentIndex: Int = 0
    var catalogFolderSegmentAccumulatedSize: Int = 0
    var catalogFolderSegmentBasePath: String = ""
    var catalogFolderSegmentPath: String = ""

    required init() {}

    func run(cmd: ParsedCommand, core: CommandCore) {
        if cmd.parameters.count == 0 {
            print("No manifest file path specified.")
            return
        }

        let manifestFile = ManifestFile.sample()

        for manifestPath in cmd.parameters {
            manifestFile.write(to: URL(fileURLWithPath: manifestPath))
        }
        print("Done.")
    }

    static func commandDefinition() -> SubcommandDefinition {
        var command = SubcommandDefinition()
        command.name = "sample"
        command.synopsis = "Write out a manifest file."
        command.hasFileParameters = true

        var parameter = ParameterInfo()
        parameter.help = "manifest file"
        command.requiredParameters.append(parameter)

        return command
    }
}
