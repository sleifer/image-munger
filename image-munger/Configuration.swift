//
//  Configuration.swift
//  image-munger
//
//  Created by Simeon Leifer on 8/27/18.
//  Copyright © 2018 droolingcat.com. All rights reserved.
//

import Foundation

enum PresetType: String {
    case none
    case smallSticker
    case mediumSticker
    case largeSticker
    case thumb256
    case imageSet
    case imageSetForLargeSticker
    case imageFileForLargeSticker
}

enum ImageFormat: String {
    case unchanged = "unchanged"
    case JPEG = "jpg"
    case PNG = "png"
    case GIF = "gif"
    case TIFF = "tif"
}

enum PackageType: String {
    case none = "none"
    case stickerPack = "stickerpack"
    case imageSet = "imageset"
    case iconSet = "iconset"
    case icns = "icns"
    case catalog = "catalog"
}

class Configuation {
    var valid: Bool
    var error: String?
    var srcDirPath: String
    var dstDirPath: String
    var manifestPath: String
    var preset: PresetType
    var validExtensions: [String]
    var outManifestPath: String?
    var outputFormat: ImageFormat
    var outputPackage: PackageType
    var outPackageReplace: Bool
    var scale: Double?
    var maxWidth: Int?
    var maxHeight: Int?

    init() {
        valid = false
        srcDirPath = ""
        dstDirPath = ""
        manifestPath = ""
        preset = .none
        validExtensions = ["jpg", "png", "gif", "tif"]
        outputFormat = .unchanged
        outputPackage = .none
        outPackageReplace = false
    }
}
