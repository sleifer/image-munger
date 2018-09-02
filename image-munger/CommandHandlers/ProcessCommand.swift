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

        var outputDir = FileManager.default.currentDirectoryPath
        if let option = cmd.option("--output") {
            outputDir = option.arguments[0].expandingTildeInPath
        }

        var manifests: [Manifest] = []

        for manifestPath in cmd.parameters {
            let additionalManifests = readManifest(manifestPath, outputDir: outputDir)
            manifests.append(contentsOf: additionalManifests)
        }

        print("Read \(manifests.count) configuration(s) from \(cmd.parameters.count) manifest file(s).")

        for manifest in manifests {
            if let error = validate(manifest: manifest) {
                print(error)
            } else if let error = collectFiles(manifest: manifest) {
                print(error)
            } else {
                process(manifest: manifest)
            }
        }

        print("Done.")
    }

    func readManifest(_ path: String, outputDir: String) -> [Manifest] {
        var manifests: [Manifest] = []
        var manifest = Manifest(path: path, outputDir: outputDir)
        do {
            let fullText = try String(contentsOfFile: path, encoding: .utf8)
            fullText.enumerateLines { (line: String, _: inout Bool) in
                if line.count > 0 {
                    if line.hasPrefix("# ") == true {
                        // comment, ignore
                    } else if line.hasPrefix("= ") == true {
                        // setting
                        let parts = line.suffix(from: 2).components(separatedBy: ",")
                        if parts.count == 2 {
                            let key = parts[0].trimmed()
                            let value = parts[1].trimmed()
                            manifest.settings[key] = value
                        }
                    } else if line.hasPrefix("--") == true {
                        // manifest separator
                        manifests.append(manifest)
                        manifest = Manifest(path: path, outputDir: outputDir)
                    } else {
                        // file
                        manifest.files.append(line)
                    }
                }
            }
            manifests.append(manifest)
        } catch {
            print("Error loading manifest (\(path)): \(error)")
        }

        return manifests
    }

    func collectFiles(manifest: Manifest) -> String? {
        let cfg = manifest.configuration

        do {
            var files = try FileManager.default.contentsOfDirectory(atPath: cfg.srcDirPath)
            files = cfg.filterByExtension(files: files)

            if manifest.files.count == 0 {
                manifest.files.append(contentsOf: files)
                return nil
            }

            let filtered = manifest.files.filter { (item: String) -> Bool in
                if files.contains(item) {
                    return true
                }
                return false
            }

            if filtered.count != manifest.files.count {
                return "Src is missing files listed in manifest."
            }
        } catch {
            return error.localizedDescription
        }

        return nil
    }

    func validate(manifest: Manifest) -> String? {
        let cfg = manifest.configuration

        if cfg.srcDirPath == "" {
            cfg.valid = false
            cfg.error = "Missing src."
            return cfg.error
        }

        if cfg.dstDirPath == "" {
            cfg.valid = false
            cfg.error = "Missing dst."
            return cfg.error
        }

        if cfg.scale != 0 {
            if cfg.maxWidth != 0 || cfg.maxHeight != 0 {
                cfg.valid = false
                cfg.error = "Can not specify scale and max-width / max-height."
                return cfg.error
            }
        }
        return nil
    }

    func clearStickerPack(folder: String) {
        let fm = FileManager.default
        do {
            let path = folder.appendingPathComponent("Contents.json")
            let json = try String(contentsOfFile: path)
            if let contents = StickerPackContents(JSONString: json) {
                for item in contents.stickers {
                    let itemPath = folder.appendingPathComponent(item.filename)
                    try fm.removeItem(atPath: itemPath)
                }
                contents.stickers.removeAll()
                let JSONString = contents.toJSONString(prettyPrint: true)
                try JSONString?.write(toFile: path, atomically: true, encoding: .utf8)
            }
        } catch {
            print("Error in clearStickerPack: \(error)")
        }
    }

    func clearCatalog(folder: String) {
        clear(folder: folder)

        do {
            let contents = CatalogContents()
            contents.info.author = "xcode"
            contents.info.version = 1
            let path = folder.appendingPathComponent("Contents.json")
            let JSONString = contents.toJSONString(prettyPrint: true)
            try JSONString?.write(toFile: path, atomically: true, encoding: .utf8)
        } catch {
            print("Error in clearCatalog: \(error)")
        }
    }

    func clear(folder: String) {
        let fm = FileManager.default
        do {
            let files = try fm.contentsOfDirectory(atPath: folder)
            for file in files {
                do {
                    try fm.removeItem(atPath: folder.appendingPathComponent(file))
                } catch {
                    print("Error deleting \(file): \(error)")
                }
            }
        } catch {
            print("Error getting contents of folder \(folder): \(error)")
        }
    }

    // swiftlint:disable cyclomatic_complexity

    func process(manifest: Manifest) {
        let cfg = manifest.configuration
        let package = cfg.outputPackage

        switch package {
        case .none:
            if cfg.outPackageReplace == true {
                clear(folder: cfg.dstDirPath)
            }
        case .stickerPack:
            if cfg.dstDirPath.hasSuffix(".stickerpack") == false {
                print("\(cfg.dstDirPath) is not a .stickerpack directory.")
                return
            }
            if cfg.outPackageReplace == true {
                clearStickerPack(folder: cfg.dstDirPath)
            }
            setStickerPackSize(cfg.dstDirPath, size: cfg.preset.stickerSizeString())
        case .imageSet:
            // no pre-action
            break
        case .iconSet:
            if cfg.dstDirPath.hasSuffix(".appiconset") == false && cfg.dstDirPath.hasSuffix(".stickersiconset") == false {
                print("\(cfg.dstDirPath) is not a .appiconset or .stickersiconset directory.")
                return
            }
            if manifest.files.count != 1 {
                print("Only 1 source image allowed when using iconset package.")
                return
            }
        case .icns:
            if cfg.dstDirPath.hasSuffix(".icns") == false {
                print("\(cfg.dstDirPath) is not a .icns file.")
                return
            }
            if manifest.files.count != 1 {
                print("Only 1 source image allowed when using icns package.")
                return
            }
        case .catalog:
            if cfg.dstDirPath.hasSuffix(".xcassets") == false {
                print("\(cfg.dstDirPath) is not a .xcassets directory.")
                return
            }
            if cfg.outPackageReplace == true {
                clearCatalog(folder: cfg.dstDirPath)
            }
        }

        print("Processing \(manifest.files.count) image(s)...")

        for file in manifest.files {
            let path = cfg.srcDirPath.appendingPathComponent(file)
            processImage(srcImagePath: path, manifest: manifest)
        }
    }

    // swiftlint:enable cyclomatic_complexity

    func scale(image: CGImage, width: Int, height: Int) -> CGImage? {
        let dstRect = CGRect(x: 0, y: 0, width: width, height: height)
        let bytesPerRow = width * 4
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let context = CGContext.init(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: UInt32(bitmapInfo.rawValue)) else {
            print("Can't create CGContext")
            return nil
        }

        context.clear(dstRect)
        context.draw(image, in: dstRect)
        return context.makeImage()
    }

    func setStickerPackSize(_ path: String, size: String) {
        var contents: StickerPackContents?

        let contentsPath = path.appendingPathComponent("Contents.json")
        do {
            let json = try String(contentsOfFile: contentsPath)
            contents = StickerPackContents(JSONString: json)
        } catch {
            print("Error in setStickerPackSize: \(error)")
        }

        if let contents = contents {
            contents.properties.gridSize = size

            do {
                let JSONString = contents.toJSONString(prettyPrint: true)
                try JSONString?.write(toFile: contentsPath, atomically: true, encoding: .utf8)
            } catch {
                print("Error in setStickerPackSize: \(error)")
            }
        }
    }

    func insertStickerToPack(_ path: String) -> String {
        let fm = FileManager.default
        var contents: StickerPackContents?

        let contentsPath = path.deletingLastPathComponent.appendingPathComponent("Contents.json")
        do {
            let json = try String(contentsOfFile: contentsPath)
            contents = StickerPackContents(JSONString: json)
        } catch {
            print("Error in insertStickerToPack: \(error)")
        }

        let stickerDirPath = path.changeFileExtension(to: "sticker")
        let stickerContentsPath = stickerDirPath.appendingPathComponent("Contents.json")
        let stickerImagePath = stickerDirPath.appendingPathComponent(path.lastPathComponent)

        do {
            try fm.createDirectory(atPath: stickerDirPath, withIntermediateDirectories: true)
        } catch {
            print("Error creating \(stickerDirPath): \(error)")
        }

        do {
            let contents = StickerContents()
            contents.info.author = "xcode"
            contents.info.version = 1
            contents.properties.filename = path.lastPathComponent
            let JSONString = contents.toJSONString(prettyPrint: true)
            try JSONString?.write(toFile: stickerContentsPath, atomically: true, encoding: .utf8)
        } catch {
            print("Error in insertStickerToPack: \(error)")
        }

        if let contents = contents {
            let newSticker = StickerPackContentsSticker()
            newSticker.filename = path.lastPathComponent.changeFileExtension(to: "sticker")
            contents.stickers.append(newSticker)

            do {
                let JSONString = contents.toJSONString(prettyPrint: true)
                try JSONString?.write(toFile: contentsPath, atomically: true, encoding: .utf8)
            } catch {
                print("Error in insertStickerToPack: \(error)")
            }
        }

        return stickerImagePath
    }

    func imageSetPathFromImagePath(_ path: String) -> String {
        var newPath = path.changeFileExtension(to: "imageset")
        newPath = newPath.changeFileSuffix(from: "@2x", to: "")
        newPath = newPath.changeFileSuffix(from: "@3x", to: "")
        return newPath
    }

    func clearImageSet(_ path: String) {
        let fm = FileManager.default
        let setPath = imageSetPathFromImagePath(path)

        do {
            try fm.removeItem(atPath: setPath)
        } catch {
            print("Error deleting \(setPath): \(error)")
        }

        do {
            try fm.createDirectory(atPath: setPath, withIntermediateDirectories: true)
        } catch {
            print("Error creating \(setPath): \(error)")
        }

        do {
            let contents = ImageSetContents()
            contents.info.author = "xcode"
            contents.info.version = 1
            let contentsPath = setPath.appendingPathComponent("Contents.json")
            let JSONString = contents.toJSONString(prettyPrint: true)
            try JSONString?.write(toFile: contentsPath, atomically: true, encoding: .utf8)
        } catch {
            print("Error in clearImageSet: \(error)")
        }
    }

    func insertImageToSet(_ path: String) -> String {
        let setPath = imageSetPathFromImagePath(path)
        var contents: ImageSetContents?

        let contentsPath = setPath.appendingPathComponent("Contents.json")
        do {
            let json = try String(contentsOfFile: contentsPath)
            contents = ImageSetContents(JSONString: json)
        } catch {
            print("Error in insertImageToSet: \(error)")
        }

        let newFileName = path.lastPathComponent
        let imageRecord = ImageSetContentsImage()
        imageRecord.idiom = "universal"
        imageRecord.filename = newFileName
        if newFileName.hasFileSuffix("@2x") == true {
            imageRecord.scale = "2x"
        } else if newFileName.hasFileSuffix("@3x") == true {
            imageRecord.scale = "3x"
        } else {
            imageRecord.scale = "1x"
        }

        if let contents = contents {
            contents.images.append(imageRecord)

            do {
                let JSONString = contents.toJSONString(prettyPrint: true)
                try JSONString?.write(toFile: contentsPath, atomically: true, encoding: .utf8)
            } catch {
                print("Error in insertImageToSet: \(error)")
            }
        }

        return setPath.appendingPathComponent(newFileName)
    }

    func write(image: CGImage, path: String) {
        if let data = CFDataCreateMutable(kCFAllocatorDefault, 0) {
            if let uttype = ImageFormat.formatForPath(path).uttype {
                if let ref = CGImageDestinationCreateWithData(data, uttype, 1, nil) {
                    CGImageDestinationAddImage(ref, image, nil)
                    CGImageDestinationFinalize(ref)
                    let nsdata = data as NSData
                    if nsdata.write(toFile: path, atomically: true) == true {
                        return
                    }
                }
            }
        }
        print("Issue writing image to \(path)")
    }

    // swiftlint:disable cyclomatic_complexity

    func processIconSet(srcImagePath: String, manifest: Manifest, plan: Plan) {
        let dstFolderPath = manifest.configuration.dstDirPath

        let contentsPath = dstFolderPath.appendingPathComponent("Contents.json")
        var contents: ImageSetContents?
        do {
            let json = try String(contentsOfFile: contentsPath)
            contents = ImageSetContents(JSONString: json)
        } catch {
            print("Error in processIconSet: \(error)")
        }

        if let contents = contents {
            for image in contents.images {
                let neededSize = image.size
                let neededScale = image.scale
                let currentFilename = image.filename

                if neededSize.count == 0 {
                    print("Missing size.")
                    return
                }
                if neededScale.count == 0 {
                    print("Missing scale.")
                    return
                }

                let sizeParts = neededSize.components(separatedBy: "x")
                let scaleParts = neededScale.components(separatedBy: "x")

                let reqScale = Double(scaleParts[0]) ?? 0.0
                let reqWidth = Double(sizeParts[0]) ?? 0.0
                let reqHeight = Double(sizeParts[1]) ?? 0.0

                let neededWidth = Int(reqWidth * reqScale)
                let neededHeight = Int(reqHeight * reqScale)

                if currentFilename.count != 0 {
                    let path = dstFolderPath.appendingPathComponent(currentFilename)
                    do {
                        try FileManager.default.removeItem(atPath: path)
                        image.filename = ""
                    } catch {
                        print("Error deleting \(path): \(error)")
                    }
                }

                if let reqSuffix = plan.requiredSuffix, srcImagePath.hasSuffix(reqSuffix) == false {
                    print("\(srcImagePath) does not have the required suffix: \(reqSuffix)")
                    continue
                }

                var dstName = srcImagePath.lastPathComponent
                if ImageFormat.formatForPath(dstName) == .unchanged {
                    print("\(srcImagePath) has an unsupported source format.")
                    continue
                }
                if plan.outputFormat != .unchanged {
                    dstName = dstName.changeFileExtension(from: dstName.pathExtension, to: plan.outputFormat.rawValue)
                }

                let newSuffix = "-\(neededSize)-\(neededScale)"
                dstName = dstName.changeFileSuffix(from: "", to: newSuffix)

                let dstPath = dstFolderPath.appendingPathComponent(dstName)

                let srcImageUrl = URL(fileURLWithPath: srcImagePath)
                let srcImageSource = CGImageSourceCreateWithURL(srcImageUrl as CFURL, nil)
                var srcImage: CGImage?
                if let srcImageSource = srcImageSource {
                    srcImage = CGImageSourceCreateImageAtIndex(srcImageSource, 0, nil)
                }

                if srcImage == nil {
                    print("Failed to load image \(srcImagePath).")
                    continue
                }

                var dstImage: CGImage?

                if let srcImage = srcImage {
                    dstImage = scale(image: srcImage, width: neededWidth, height: neededHeight)
                }

                if let image = dstImage {
                    write(image: image, path: dstPath)
                } else if let image = srcImage {
                    write(image: image, path: dstPath)
                }

                image.filename = dstName
            }

            do {
                let JSONString = contents.toJSONString(prettyPrint: true)
                try JSONString?.write(toFile: contentsPath, atomically: true, encoding: .utf8)
            } catch {
                print("Error in processIconSet: \(error)")
            }
        }
    }

    // swiftlint:enable cyclomatic_complexity

    func processIcns(srcImagePath: String, manifest: Manifest, plan: Plan) {
        let dstFilePath = manifest.configuration.dstDirPath
        let dstFolderPath = dstFilePath.changeFileExtension(to: "iconset")

        do {
            try FileManager.default.createDirectory(atPath: dstFolderPath, withIntermediateDirectories: true)
        } catch {
            print("Error creating \(dstFolderPath): \(error)")
        }

        var plans: [Plan] = []
        plans.append(Plan(scale: 1, boxWidth: 16, boxHeight: 16))
        plans.append(Plan(scale: 2, boxWidth: 16, boxHeight: 16))
        plans.append(Plan(scale: 1, boxWidth: 32, boxHeight: 32))
        plans.append(Plan(scale: 2, boxWidth: 32, boxHeight: 32))
        plans.append(Plan(scale: 1, boxWidth: 128, boxHeight: 128))
        plans.append(Plan(scale: 2, boxWidth: 128, boxHeight: 128))
        plans.append(Plan(scale: 1, boxWidth: 256, boxHeight: 256))
        plans.append(Plan(scale: 2, boxWidth: 256, boxHeight: 256))
        plans.append(Plan(scale: 1, boxWidth: 512, boxHeight: 512))
        plans.append(Plan(scale: 2, boxWidth: 512, boxHeight: 512))

        for onePlan in plans {
            let neededWidth = Int(onePlan.scale * Double(onePlan.boxWidth))
            let neededHeight = Int(onePlan.scale * Double(onePlan.boxHeight))

            if let reqSuffix = plan.requiredSuffix, srcImagePath.hasSuffix(reqSuffix) == false {
                print("\(srcImagePath) does not have the required suffix: \(reqSuffix)")
                return
            }

            var dstName = "icon_".appendingPathExtension(srcImagePath.pathExtension) ?? "icon_"

            if ImageFormat.formatForPath(srcImagePath) == .unchanged {
                print("\(srcImagePath) has an unsupported source format.")
                continue
            }
            if plan.outputFormat != .unchanged {
                dstName = dstName.changeFileExtension(from: dstName.pathExtension, to: plan.outputFormat.rawValue)
            }

            var newSuffix = "\(neededWidth)x\(neededHeight)"
            if onePlan.scale == 2.0 {
                newSuffix += "@2x"
            }
            dstName = dstName.changeFileSuffix(from: "", to: newSuffix)
            let dstPath = dstFolderPath.appendingPathComponent(dstName)

            let srcImageUrl = URL(fileURLWithPath: srcImagePath)
            let srcImageSource = CGImageSourceCreateWithURL(srcImageUrl as CFURL, nil)
            var srcImage: CGImage?
            if let srcImageSource = srcImageSource {
                srcImage = CGImageSourceCreateImageAtIndex(srcImageSource, 0, nil)
            }

            if srcImage == nil {
                print("Failed to load image \(srcImagePath).")
                continue
            }

            var dstImage: CGImage?

            if let srcImage = srcImage {
                dstImage = scale(image: srcImage, width: neededWidth, height: neededHeight)
            }

            if let image = dstImage {
                write(image: image, path: dstPath)
            } else if let image = srcImage {
                write(image: image, path: dstPath)
            }
        }

        let runner = ProcessRunner("iconutil", args: ["--convert", "icns", "--output", dstFilePath, dstFolderPath])
        runner.start()

        do {
            try FileManager.default.removeItem(atPath: dstFolderPath)
        } catch {
            print("Error deleting \(dstFolderPath): \(error)")
        }
    }

    // swiftlint:disable cyclomatic_complexity

    func processImage(srcImagePath: String, manifest: Manifest) {
        print("Processing: \(srcImagePath.lastPathComponent)")

        var oneTimeDone: Bool = false

        for plan in manifest.configuration.plans {

            switch manifest.configuration.outputPackage {
            case .none:
                break
            case .stickerPack:
                break
            case .imageSet:
                break
            case .iconSet:
                processIconSet(srcImagePath: srcImagePath, manifest: manifest, plan: plan)
                continue
            case .icns:
                processIcns(srcImagePath: srcImagePath, manifest: manifest, plan: plan)
                continue
            case .catalog:
                break
            }

            if let reqSuffix = plan.requiredSuffix, srcImagePath.hasSuffix(reqSuffix) == false {
                print("\(srcImagePath) does not have the required suffix: \(reqSuffix)")
                continue
            }

            var dstName = srcImagePath.lastPathComponent
            let dstFormat = ImageFormat.formatForPath(dstName)
            if dstFormat == .unchanged {
                print("\(srcImagePath) has an unsupported source format.")
                continue
            }
            if plan.outputFormat != .unchanged {
                dstName = dstName.changeFileExtension(from: dstName.pathExtension, to: plan.outputFormat.rawValue)
            }

            var dstPath = manifest.configuration.dstDirPath.appendingPathComponent(dstName)

            if plan.removeSuffix != nil || plan.addSuffix != nil {
                dstPath = dstPath.changeFileSuffix(from: plan.removeSuffix ?? "", to: plan.addSuffix ?? "")
            }

            let srcImageUrl = URL(fileURLWithPath: srcImagePath)
            let srcImageSource = CGImageSourceCreateWithURL(srcImageUrl as CFURL, nil)
            var srcImage: CGImage?
            if let srcImageSource = srcImageSource {
                srcImage = CGImageSourceCreateImageAtIndex(srcImageSource, 0, nil)
            }

            if srcImage == nil {
                print("Failed to load image \(srcImagePath).")
                continue
            }

            var dstImage: CGImage?

            if let srcImage = srcImage {
                if plan.scale != 0 {
                    if plan.scale != 1 {
                        let newWidth = (Double(srcImage.width) * plan.scale).rounded(.down)
                        let newHeight = (Double(srcImage.height) * plan.scale).rounded(.down)
                        dstImage = scale(image: srcImage, width: Int(newWidth), height: Int(newHeight))
                    }
                } else if plan.boxWidth == 0 && plan.boxHeight == 0 {
                    // no action
                } else if plan.boxWidth == 0 {
                    let newWidth = (Double(srcImage.width) * Double(plan.boxHeight) / Double(srcImage.height)).rounded(.down)
                    let newHeight = plan.boxHeight
                    dstImage = scale(image: srcImage, width: Int(newWidth), height: newHeight)
                } else if plan.boxHeight == 0 {
                    let newWidth = plan.boxWidth
                    let newHeight = (Double(srcImage.height) * Double(plan.boxWidth) / Double(srcImage.width)).rounded(.down)
                    dstImage = scale(image: srcImage, width: newWidth, height: Int(newHeight))
                } else {
                    var newWidth = Int((Double(srcImage.width) * Double(plan.boxHeight) / Double(srcImage.height)).rounded(.down))
                    var newHeight = plan.boxHeight
                    if newWidth > plan.boxWidth {
                        newWidth = plan.boxWidth
                        newHeight = Int((Double(srcImage.height) * Double(plan.boxWidth) / Double(srcImage.width)).rounded(.down))
                    }
                    dstImage = scale(image: srcImage, width: newWidth, height: newHeight)
                }
            }

            switch manifest.configuration.outputPackage {
            case .none:
                break
            case .stickerPack:
                dstPath = insertStickerToPack(dstPath)
            case .imageSet:
                if oneTimeDone == false {
                    clearImageSet(dstPath)
                    oneTimeDone = true
                }
                dstPath = insertImageToSet(dstPath)
            case .iconSet:
                break
            case .icns:
                break
            case .catalog:
                break
            }

            if let image = dstImage {
                write(image: image, path: dstPath)
            } else if let image = srcImage {
                write(image: image, path: dstPath)
            }
        }
    }

    // swiftlint:enable cyclomatic_complexity
}