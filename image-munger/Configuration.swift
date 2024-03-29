//
//  Configuration.swift
//  image-munger
//
//  Created by Simeon Leifer on 8/27/18.
//  Copyright © 2018 droolingcat.com. All rights reserved.
//

import Foundation
import AppKit

enum ImageScales {
    case oneX
    case twoX
    case threeX
}

enum PresetType: String, Codable {
    case none
    case smallSticker
    case mediumSticker
    case largeSticker
    case thumb256
    case imageSet
    case stickerImageSet1
    case stickerImageSet2
    case stickerImageSet3
    case stickerImageSet12
    case stickerImageSet13
    case stickerImageSet23
    case stickerImageSet123
    case stickerImageFiles1
    case stickerImageFiles2
    case stickerImageFiles3
    case stickerImageFiles12
    case stickerImageFiles13
    case stickerImageFiles23
    case stickerImageFiles123

    func stickerSizeString() -> String {
        switch self {
        case .smallSticker:
            return "small"
        case .mediumSticker:
            return "regular"
        case .largeSticker:
            return "large"
        default:
            return "regular"
        }
    }
}

enum ImageFormat: String, Codable {
    case unchanged = "unchanged"
    case JPEG = "jpg"
    case PNG = "png"
    case GIF = "gif"
    case TIFF = "tif"

    var uttype: CFString? {
        switch self {
        case .unchanged:
            return nil
        case .JPEG:
            return kUTTypeJPEG
        case .PNG:
            return kUTTypePNG
        case .GIF:
            return kUTTypeGIF
        case .TIFF:
            return kUTTypeTIFF
        }
    }

    static func formatForPath(_ path: String) -> ImageFormat {
        let ext = path.pathExtension
        switch ext {
        case "tiff":
            return .TIFF
        case "jpeg":
            return .JPEG
        default:
            return ImageFormat(rawValue: ext) ?? .unchanged
        }
    }
}

enum PackageType: String, Codable {
    case none = "none"
    case stickerPack = "stickerpack"
    case imageSet = "imageset"
    case iconSet = "iconset"
    case icns = "icns"
    case catalog = "catalog"
    case catalogFolder = "catalogfolder"
}

struct Color: Codable {
    var red: CGFloat
    var green: CGFloat
    var blue: CGFloat
    var alpha: CGFloat?

    var nsColor: NSColor {
        return NSColor(red: red, green: green, blue: blue, alpha: alpha ?? 1)
    }
}

class Configuation: Codable, YAMLReadWrite {
    typealias HostClass = Configuation

    var backgroundColor: Color?
    var catalogFolderMaxSize: Int
    var catalogFolderNamespace: Bool
    var catalogFolderTag: String?
    var dstDirPath: String
    var error: String?
    var manifestPath: String
    var masksToo: Bool
    var maxHeight: Int
    var maxWidth: Int
    var outContactSheetPath: String?
    var outManifestPath: String?
    var outPackageReplace: Bool
    var outputFormat: ImageFormat
    var outputPackage: PackageType
    var ovalSrcDirPath: String
    var preset: PresetType
    var scale: Double
    var squareSrcDirPath: String
    var srcDirPath: String
    var valid: Bool
    var validExtensions: [String]

    lazy var plans: [Plan] = {
        return makePlans()
    }()

    init() {
        backgroundColor = nil
        catalogFolderMaxSize = 0
        catalogFolderNamespace = false
        catalogFolderTag = nil
        dstDirPath = ""
        error = nil
        manifestPath = ""
        masksToo = false
        maxHeight = 0
        maxWidth = 0
        outContactSheetPath = nil
        outManifestPath = nil
        outPackageReplace = false
        outputFormat = .unchanged
        outputPackage = .none
        ovalSrcDirPath = ""
        preset = .none
        scale = 0.0
        squareSrcDirPath = ""
        srcDirPath = ""
        valid = false
        validExtensions = ["jpg", "png", "gif", "tif"]
    }

    func filterByExtension(files: [String]) -> [String] {
        return files.filter({ (item: String) -> Bool in
            if validExtensions.contains(item.pathExtension) {
                return true
            }
            return false
        })
    }

    // swiftlint:disable cyclomatic_complexity

    func makePlans() -> [Plan] {
        switch preset {
        case .none:
            return makeNonePlans()
        case .smallSticker:
            return makeSmallStickerPlans()
        case .mediumSticker:
            return makeMediumStickerPlans()
        case .largeSticker:
            return makeLargeStickerPlans()
        case .thumb256:
            return makeThumb256Plans()
        case .imageSet:
            return makeImageSetPlans()
        case .stickerImageSet1:
            return makeStickerImageSetPlans([.oneX])
        case .stickerImageSet2:
            return makeStickerImageSetPlans([.twoX])
        case .stickerImageSet3:
            return makeStickerImageSetPlans([.threeX])
        case .stickerImageSet12:
            return makeStickerImageSetPlans([.oneX, .twoX])
        case .stickerImageSet13:
            return makeStickerImageSetPlans([.oneX, .threeX])
        case .stickerImageSet23:
            return makeStickerImageSetPlans([.twoX, .threeX])
        case .stickerImageSet123:
            return makeStickerImageSetPlans([.oneX, .twoX, .threeX])
        case .stickerImageFiles1:
            return makeStickerImageFilesPlans([.oneX])
        case .stickerImageFiles2:
            return makeStickerImageFilesPlans([.twoX])
        case .stickerImageFiles3:
            return makeStickerImageFilesPlans([.threeX])
        case .stickerImageFiles12:
            return makeStickerImageFilesPlans([.oneX, .twoX])
        case .stickerImageFiles13:
            return makeStickerImageFilesPlans([.oneX, .threeX])
        case .stickerImageFiles23:
            return makeStickerImageFilesPlans([.twoX, .threeX])
        case .stickerImageFiles123:
            return makeStickerImageFilesPlans([.oneX, .twoX, .threeX])
        }
    }

    // swiftlint:enable cyclomatic_complexity

    func makeNonePlans() -> [Plan] {
        var plans: [Plan] = []

        let plan = Plan(scale: self.scale, boxWidth: self.maxWidth, boxHeight: self.maxHeight, outputFormat: self.outputFormat, outputPackage: self.outputPackage)
        plans.append(plan)

        return plans
    }

    func makeSmallStickerPlans() -> [Plan] {
        var plans: [Plan] = []

        let plan = Plan(boxWidth: 300, boxHeight: 300, aspectWithMaxBox: true, outputFormat: .PNG, outputPackage: self.outputPackage, addSuffix: "@3x")
        plans.append(plan)

        return plans
    }

    func makeMediumStickerPlans() -> [Plan] {
        var plans: [Plan] = []

        let plan = Plan(boxWidth: 408, boxHeight: 408, aspectWithMaxBox: true, outputFormat: .PNG, outputPackage: self.outputPackage, addSuffix: "@3x")
        plans.append(plan)

        return plans
    }

    func makeLargeStickerPlans() -> [Plan] {
        var plans: [Plan] = []

        let plan = Plan(boxWidth: 618, boxHeight: 618, aspectWithMaxBox: true, outputFormat: .PNG, outputPackage: self.outputPackage, addSuffix: "@3x")
        plans.append(plan)

        return plans
    }

    func makeThumb256Plans() -> [Plan] {
        var plans: [Plan] = []

        let plan = Plan(boxWidth: 256, boxHeight: 256, aspectWithMaxBox: true, outputFormat: self.outputFormat, outputPackage: self.outputPackage)
        plans.append(plan)

        return plans
    }

    func makeImageSetPlans() -> [Plan] {
        var plans: [Plan] = []

        if self.maxWidth != 0 && self.maxHeight != 0 {
            let plan1 = Plan(boxWidth: self.maxWidth / 3, boxHeight: self.maxHeight / 3, aspectWithMaxBox: true, outputFormat: self.outputFormat, outputPackage: self.outputPackage)
            plans.append(plan1)

            let plan2 = Plan(boxWidth: self.maxWidth / 3 * 2, boxHeight: self.maxHeight / 3 * 2, aspectWithMaxBox: true, outputFormat: self.outputFormat, outputPackage: self.outputPackage, addSuffix: "@2x")
            plans.append(plan2)

            let plan3 = Plan(boxWidth: self.maxWidth, boxHeight: self.maxHeight, aspectWithMaxBox: true, outputFormat: self.outputFormat, outputPackage: self.outputPackage, addSuffix: "@3x")
            plans.append(plan3)
        } else {
            let plan1 = Plan(scale: 1.0/3.0, outputFormat: self.outputFormat, outputPackage: self.outputPackage, requiredSuffix: "@3x", removeSuffix: "@3x", addSuffix: "")
            plans.append(plan1)

            let plan2 = Plan(scale: 2.0/3.0, outputFormat: self.outputFormat, outputPackage: self.outputPackage, requiredSuffix: "@3x", removeSuffix: "@3x", addSuffix: "@2x")
            plans.append(plan2)

            let plan3 = Plan(scale: 1.0, outputFormat: self.outputFormat, outputPackage: self.outputPackage, requiredSuffix: "@3x")
            plans.append(plan3)
        }

        return plans
    }

    func makeStickerImageSetPlans(_ scales: Set<ImageScales>) -> [Plan] {
        var plans: [Plan] = []

        if scales.contains(.oneX) {
            let plan1 = Plan(boxWidth: 206, boxHeight: 206, outputFormat: .PNG, outputPackage: self.outputPackage, addSuffix: "")
            plans.append(plan1)
        } else {
            let plan1 = Plan(boxWidth: 1, boxHeight: 1, outputFormat: .PNG, outputPackage: self.outputPackage, addSuffix: "")
            plans.append(plan1)
        }

        if scales.contains(.twoX) {
            let plan2 = Plan(boxWidth: 412, boxHeight: 412, outputFormat: .PNG, outputPackage: self.outputPackage, addSuffix: "@2x")
            plans.append(plan2)
        } else {
            let plan2 = Plan(boxWidth: 1, boxHeight: 1, outputFormat: .PNG, outputPackage: self.outputPackage, addSuffix: "@2x")
            plans.append(plan2)
        }

        if scales.contains(.threeX) {
            let plan3 = Plan(boxWidth: 618, boxHeight: 618, outputFormat: .PNG, outputPackage: self.outputPackage, addSuffix: "@3x")
            plans.append(plan3)
        } else {
            let plan3 = Plan(boxWidth: 1, boxHeight: 1, outputFormat: .PNG, outputPackage: self.outputPackage, addSuffix: "@3x")
            plans.append(plan3)
        }

        return plans
    }

    func makeStickerImageFilesPlans(_ scales: Set<ImageScales>) -> [Plan] {
        var plans: [Plan] = []

        if scales.contains(.oneX) {
            let plan1 = Plan(boxWidth: 206, boxHeight: 206, outputFormat: .PNG, outputPackage: self.outputPackage, addSuffix: "@1x")
            plans.append(plan1)
        }

        if scales.contains(.twoX) {
            let plan2 = Plan(boxWidth: 412, boxHeight: 412, outputFormat: .PNG, outputPackage: self.outputPackage, addSuffix: "@2x")
            plans.append(plan2)
        }

        if scales.contains(.threeX) {
            let plan3 = Plan(boxWidth: 618, boxHeight: 618, outputFormat: .PNG, outputPackage: self.outputPackage, addSuffix: "@3x")
            plans.append(plan3)
        }

        return plans
    }
}
