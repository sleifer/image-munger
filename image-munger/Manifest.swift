//
//  Manifest.swift
//  image-munger
//
//  Created by Simeon Leifer on 8/26/18.
//  Copyright © 2018 droolingcat.com. All rights reserved.
//

import Foundation
import CommandLineCore

class Manifest {
    var manifestPath: String
    var outputDir: String
    var settings: [String: String]
    var files: [String]
    var ovalFiles: [String]
    var squareFiles: [String]

    lazy var configuration: Configuation = {
        return makeConfiguration()
    }()

    init(path: String, outputDir: String) {
        self.manifestPath = CommandCore.core!.baseSubPath(path)
        self.outputDir = CommandCore.core!.baseSubPath(outputDir)
        settings = [:]
        files = []
        ovalFiles = []
        squareFiles = []
    }

    func expandPathSetting(_ path: String) -> String {
        if path.hasPrefix("~~~") {
            return outputDir.appendingPathComponent(path.suffix(from: 3))
        } else if path.hasPrefix("~~") {
            return manifestPath.deletingLastPathComponent.appendingPathComponent(path.suffix(from: 2))
        } else {
            return path.expandingTildeInPath
        }
    }

    // swiftlint:disable cyclomatic_complexity

    func makeConfiguration() -> Configuation {
        let config = Configuation()
        for (key, value) in settings {
            switch key {
            case "src":
                config.srcDirPath = expandPathSetting(value)
            case "src-oval":
                config.ovalSrcDirPath = expandPathSetting(value)
            case "src-square":
                config.squareSrcDirPath = expandPathSetting(value)
            case "dst":
                config.dstDirPath = expandPathSetting(value)
            case "preset":
                if let theValue = PresetType(rawValue: value) {
                    config.preset = theValue
                }
            case "valid-format":
                config.validExtensions = value.components(separatedBy: ",").map { (item) -> String in
                    return item.trimmed()
                }
            case "out-manifest":
                config.outManifestPath = expandPathSetting(value)
            case "out-format":
                if let theValue = ImageFormat(rawValue: value) {
                    config.outputFormat = theValue
                }
            case "out-package":
                if let theValue = PackageType(rawValue: value) {
                    config.outputPackage = theValue
                }
            case "out-package-replace":
                if value.lowercased() == "true" || Int(value) != 0 {
                    config.outPackageReplace = true
                } else {
                    config.outPackageReplace = false
                }
            case "scale":
                config.scale = Double(value) ?? 0.0
            case "max-px":
                config.maxWidth = Int(value) ?? 0
                config.maxHeight = config.maxWidth
            case "max-width-px":
                config.maxWidth = Int(value) ?? 0
            case "max-height-px":
                config.maxHeight = Int(value) ?? 0
            default:
                break
            }
        }
        return config
    }

    // swiftlint:enable cyclomatic_complexity
}
