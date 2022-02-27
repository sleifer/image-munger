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

class SampleManifestCommand {
    var manifest: Manifest = .init()
    var catalogFolderSegmentMaxSize: Int = 0
    var catalogFolderSegmentIndex: Int = 0
    var catalogFolderSegmentAccumulatedSize: Int = 0
    var catalogFolderSegmentBasePath: String = ""
    var catalogFolderSegmentPath: String = ""

    required init() {}

    func run(outputPath: String) {
        let manifestFile = ManifestFile.sample()

        manifestFile.write(to: URL(fileURLWithPath: outputPath.fullPath))
        print("Done.")
    }
}
