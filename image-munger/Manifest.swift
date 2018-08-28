//
//  Manifest.swift
//  image-munger
//
//  Created by Simeon Leifer on 8/26/18.
//  Copyright © 2018 droolingcat.com. All rights reserved.
//

import Foundation

class Manifest {
    var path: String
    var settings: [String: String]
    var files: [String]

    lazy var configuration: Configuation = {
        return makeConfiguration()
    }()

    init(path: String) {
        self.path = path
        settings = [:]
        files = []
    }

    // swiftlint:disable cyclomatic_complexity

    func makeConfiguration() -> Configuation {
        let config = Configuation()
        for (key, value) in settings {
            switch key {
            case "src":
                if value.hasPrefix("~~") {
                    config.srcDirPath = path.deletingLastPathComponent.appendingPathComponent(value.suffix(from: 2))
                } else {
                    config.srcDirPath = value.expandingTildeInPath
                }
            case "dst":
                if value.hasPrefix("~~") {
                    config.dstDirPath = path.deletingLastPathComponent.appendingPathComponent(value.suffix(from: 2))
                } else {
                    config.dstDirPath = value.expandingTildeInPath
                }
            case "preset":
                if let theValue = PresetType(rawValue: value) {
                    config.preset = theValue
                }
            case "valid-format":
                break
            case "out-manifest":
                if value.hasPrefix("~~") {
                    config.outManifestPath = path.deletingLastPathComponent.appendingPathComponent(value.suffix(from: 2))
                } else {
                    config.outManifestPath = value.expandingTildeInPath
                }
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
