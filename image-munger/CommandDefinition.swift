//
//  CommandDefinition.swift
//  project-tool
//
//  Created by Simeon Leifer on 10/10/17.
//  Copyright © 2017 droolingcat.com. All rights reserved.
//

import Foundation
import CommandLineCore

func makeCommandDefinition() -> CommandDefinition {
    var definition = CommandDefinition()
    definition.help = "A command-line tool to help automate image processing for projects."

    var version = CommandOption()
    version.longOption = "--version"
    version.help = "Show tool version information"
    definition.options.append(version)

    var help = CommandOption()
    help.shortOption = "-h"
    help.longOption = "--help"
    help.help = "Show this help"
    definition.options.append(help)

    definition.subcommands.append(processCommand())

    definition.defaultSubcommand = "process"

    return definition
}

private func processCommand() -> SubcommandDefinition {
    var command = SubcommandDefinition()
    command.name = "process"
    command.synopsis = "Process images according to manifest file."
    command.hasFileParameters = true

    var output = CommandOption()
    output.shortOption = "-o"
    output.longOption = "--output"
    output.help = "Output directory"
    output.argumentCount = 1
    output.hasFileArguments = true
    command.options.append(output)

    var parameter = ParameterInfo()
    parameter.help = "manifest file"
    command.requiredParameters.append(parameter)

    return command
}
