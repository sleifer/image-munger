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

        var manifests: [Manifest] = []

        for manifestPath in cmd.parameters {
            let additionalManifests = readManifest(manifestPath)
            manifests.append(contentsOf: additionalManifests)
        }

        print("Read \(manifests.count) configuration(s) from \(cmd.parameters.count) manifest file(s).")

        for manifest in manifests {
            process(manifest: manifest)
        }

        print("Done.")
    }

    func readManifest(_ path: String) -> [Manifest] {
        var manifests: [Manifest] = []
        var manifest = Manifest(path: path)
        do {
            let fullText = try String(contentsOfFile: path, encoding: .utf8)
            fullText.enumerateLines { (line: String, _: inout Bool) in
                if line.count > 0 {
                    if line.hasPrefix("# ") == true {
                        // comment, ignore
                    } else if line.hasPrefix("= ") == true {
                        // setting
                        let parts = line.components(separatedBy: ",")
                        if parts.count == 2 {
                            let key = parts[0].trimmed()
                            let value = parts[1].trimmed()
                            manifest.settings[key] = value
                        }
                    } else if line.hasPrefix("--") == true {
                        // manifest separator
                        manifests.append(manifest)
                        manifest = Manifest(path: path)
                    } else {
                        // file
                        manifest.files.append(line)
                    }
                }
                print("[\(line)]")
            }
        } catch {
            print("Error loading manifest (\(path)): \(error)")
        }

        return manifests
    }

    func process(manifest: Manifest) {
        // COPY func processOneConfiguration
    }
}
