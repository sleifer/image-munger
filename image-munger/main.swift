//
//  main.swift
//  image-munger
//
//  Created by Simeon Leifer on 8/24/18.
//  Copyright © 2018 droolingcat.com. All rights reserved.
//

import Foundation
import CommandLineCore

let toolVersion = "0.1.9"

func main() {
    let core = CommandCore()
    core.set(version: toolVersion)
    core.set(help: "A command-line tool to help automate image processing for projects.")
    core.set(defaultCommand: "process")

    core.add(command: ProcessCommand.self)

    #if DEBUG
    // for testing in Xcode
    let args = ["imp"]
    #else
    let args = CommandLine.arguments
    #endif

    core.process(args: args)
}

main()
