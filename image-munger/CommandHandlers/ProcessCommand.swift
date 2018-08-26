//
//  ProcessCommand.swift
//  image-munger
//
//  Created by Simeon Leifer on 8/25/18.
//  Copyright © 2018 droolingcat.com. All rights reserved.
//

import Foundation
import CommandLineCore

class ProcessCommand: Command {
    override func run(cmd: ParsedCommand) {
        if cmd.parameters.count == 0 {
            print("No manifest file specified.")
            return
        }

        print("Process: \(cmd.parameters[0])")
    }
}
