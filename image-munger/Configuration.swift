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

enum ImageFormat: String {
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
    var scale: Double
    var maxWidth: Int
    var maxHeight: Int

    lazy var plans: [Plan] = {
        return makePlans()
    }()

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
        scale = 0.0
        maxWidth = 0
        maxHeight = 0
    }

    func filterByExtension(files: [String]) -> [String] {
        return files.filter({ (item: String) -> Bool in
            if validExtensions.contains(item.pathExtension) {
                return true
            }
            return false
        })
    }

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
        case .imageSetForLargeSticker:
            return makeImageSetForLargeStickerPlans()
        case .imageFileForLargeSticker:
            return makeImageFileForLargeStickerPlans()
        }
    }

    func makeNonePlans() -> [Plan] {
        var plans: [Plan] = []

        let plan = Plan(scale: self.scale, boxWidth: self.maxWidth, boxHeight: self.maxHeight, outputFormat: self.outputFormat, outputPackage: self.outputPackage)
        plans.append(plan)

        return plans
    }

    func makeSmallStickerPlans() -> [Plan] {
        var plans: [Plan] = []

        let plan = Plan(boxWidth: 300, boxHeight: 300, outputFormat: .PNG, outputPackage: self.outputPackage)
        plans.append(plan)

        return plans
    }

    func makeMediumStickerPlans() -> [Plan] {
        var plans: [Plan] = []

        let plan = Plan(boxWidth: 408, boxHeight: 408, outputFormat: .PNG, outputPackage: self.outputPackage)
        plans.append(plan)

        return plans
    }

    func makeLargeStickerPlans() -> [Plan] {
        var plans: [Plan] = []

        let plan = Plan(boxWidth: 618, boxHeight: 618, outputFormat: .PNG, outputPackage: self.outputPackage)
        plans.append(plan)

        return plans
    }

    func makeThumb256Plans() -> [Plan] {
        var plans: [Plan] = []

        let plan = Plan(boxWidth: 256, boxHeight: 256, outputFormat: self.outputFormat, outputPackage: self.outputPackage)
        plans.append(plan)

        return plans
    }

    func makeImageSetPlans() -> [Plan] {
        var plans: [Plan] = []

        let plan1 = Plan(scale: 0.33, outputFormat: self.outputFormat, outputPackage: self.outputPackage, requiredSuffix: "@3x", removeSuffix: "@3x", addSuffix: "")
        plans.append(plan1)

        let plan2 = Plan(scale: 0.66, outputFormat: self.outputFormat, outputPackage: self.outputPackage, requiredSuffix: "@3x", removeSuffix: "@3x", addSuffix: "@2x")
        plans.append(plan2)

        let plan3 = Plan(scale: 1.0, outputFormat: self.outputFormat, outputPackage: self.outputPackage, requiredSuffix: "@3x")
        plans.append(plan3)

        return plans
    }

    func makeImageSetForLargeStickerPlans() -> [Plan] {
        var plans: [Plan] = []

        let plan1 = Plan(boxWidth: 1, boxHeight: 1, outputFormat: .PNG, outputPackage: self.outputPackage, addSuffix: "")
        plans.append(plan1)

        let plan2 = Plan(boxWidth: 412, boxHeight: 412, outputFormat: .PNG, outputPackage: self.outputPackage, addSuffix: "@2x")
        plans.append(plan2)

        let plan3 = Plan(boxWidth: 618, boxHeight: 618, outputFormat: .PNG, outputPackage: self.outputPackage, addSuffix: "@3x")
        plans.append(plan3)

        return plans
    }

    func makeImageFileForLargeStickerPlans() -> [Plan] {
        var plans: [Plan] = []

        let plan2 = Plan(boxWidth: 412, boxHeight: 412, outputFormat: .PNG, outputPackage: self.outputPackage, addSuffix: "@2x")
        plans.append(plan2)

        let plan3 = Plan(boxWidth: 618, boxHeight: 618, outputFormat: .PNG, outputPackage: self.outputPackage, addSuffix: "@3x")
        plans.append(plan3)

        return plans
    }
}