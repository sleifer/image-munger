//
//  Manifest.swift
//  image-munger
//
//  Created by Simeon Leifer on 8/26/18.
//  Copyright © 2018 droolingcat.com. All rights reserved.
//

import Foundation
import CommandLineCore
import AppKit

class Manifest {
    var manifestPath: String
    var outputDir: String
    var settings: ManifestFile
    var files: [String]
    var ovalFiles: [String]
    var squareFiles: [String]

    lazy var configuration: Configuation = {
        return makeConfiguration()
    }()

    init() {
        self.manifestPath = ""
        self.outputDir = ""
        settings = ManifestFile()
        files = []
        ovalFiles = []
        squareFiles = []
    }

    init(path: String, outputDir: String, manifestFile: ManifestFile) {
        self.manifestPath = cwd.baseSubPath(path)
        self.outputDir = cwd.baseSubPath(outputDir)
        settings = manifestFile
        files = settings.files ?? []
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

        if let value = settings.src {
            config.srcDirPath = expandPathSetting(value)
        }
        if let value = settings.srcOval {
            config.ovalSrcDirPath = expandPathSetting(value)
        }
        if let value = settings.srcSquare {
            config.squareSrcDirPath = expandPathSetting(value)
        }
        if let value = settings.dst {
            config.dstDirPath = expandPathSetting(value)
        }
        if let value = settings.preset {
            if let theValue = PresetType(rawValue: value) {
                config.preset = theValue
            }
        }
        if let value = settings.backgroundColor {
            let parts = value.components(separatedBy: ":").map { (item) -> CGFloat in
                return CGFloat(Double(item.trimmed()) ?? 0)
            }
            if parts.count == 3 {
                config.backgroundColor = Color(red: parts[0] / 255.0, green: parts[1] / 255.0, blue: parts[2] / 255.0)
            } else if parts.count == 4 {
                config.backgroundColor = Color(red: parts[0] / 255.0, green: parts[1] / 255.0, blue: parts[2] / 255.0, alpha: parts[3] / 255.0)
            }
        }
        if let value = settings.validFormat {
            config.validExtensions = value.components(separatedBy: ":").map { (item) -> String in
                return item.trimmed()
            }
        }
        if let value = settings.outManifest {
            config.outManifestPath = expandPathSetting(value)
        }
        if let value = settings.outContactSheet {
            config.outContactSheetPath = expandPathSetting(value)
        }
        if let value = settings.outFormat {
            if let theValue = ImageFormat(rawValue: value) {
                config.outputFormat = theValue
            }
        }
        if let value = settings.outPackage {
            if let theValue = PackageType(rawValue: value) {
                config.outputPackage = theValue
            }
        }
        if let value = settings.masksToo {
            if value.lowercased() == "true" || Int(value) != 0 {
                config.masksToo = true
            } else {
                config.masksToo = false
            }
        }
        if let value = settings.outPackageReplace {
            if value.lowercased() == "true" || Int(value) != 0 {
                config.outPackageReplace = true
            } else {
                config.outPackageReplace = false
            }
        }
        if let value = settings.catalogFolderNamespace {
            if value.lowercased() == "true" || Int(value) != 0 {
                config.catalogFolderNamespace = true
            } else {
                config.catalogFolderNamespace = false
            }
        }
        if let value = settings.catalogFolderTag {
            config.catalogFolderTag = value
        }
        if let value = settings.catalogFolderMaxSize {
            config.catalogFolderMaxSize = Int(value) ?? 0
        }
        if let value = settings.scale {
            config.scale = Double(value) ?? 0.0
        }
        if let value = settings.maxPx {
            config.maxWidth = Int(value) ?? 0
            config.maxHeight = config.maxWidth
        }
        if let value = settings.maxWidthPx {
            config.maxWidth = Int(value) ?? 0
        }
        if let value = settings.maxHeightPx {
            config.maxHeight = Int(value) ?? 0
        }
        return config
    }

    // swiftlint:enable cyclomatic_complexity
}
