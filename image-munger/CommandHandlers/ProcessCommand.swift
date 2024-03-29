//
//  ProcessCommand.swift
//  image-munger
//
//  Created by Simeon Leifer on 8/25/18.
//  Copyright © 2018 droolingcat.com. All rights reserved.
//

import AppKit
import CommandLineCore
import Foundation

enum ProcessError: Error, LocalizedError {
    case validate(String)
    case collectFiles(String)

    public var errorDescription: String? {
        switch self {
        case .validate(let value):
            return "validate Error: \(value)"
        case .collectFiles(let value):
            return "collectFiles Error: \(value)"
        }
    }
}

enum ProcessMode {
    case normal
    case mask
}

enum SourceFileGroup {
    case general
    case oval
    case square
}

enum ScaleMode {
    case aspectFit
    case fill
}

class ProcessCommand {
    var manifest: Manifest = .init()
    var catalogFolderSegmentMaxSize: Int = 0
    var catalogFolderSegmentIndex: Int = 0
    var catalogFolderSegmentAccumulatedSize: Int = 0
    var catalogFolderSegmentBasePath: String = ""
    var catalogFolderSegmentPath: String = ""

    required init() {}

    func run(inputPaths: [String], outputDirPath: String?) {
        var outputDir = FileManager.default.currentDirectoryPath
        if let outputDirPath = outputDirPath {
            outputDir = outputDirPath.expandingTildeInPath
        }

        var manifests: [Manifest] = []

        for manifestPath in inputPaths {
            let result = ManifestFile.multiRead(contentsOf: URL(fileURLWithPath: manifestPath.fullPath))
            switch result {
            case .success(let manifestFiles):
                let additionalManifests = manifestFiles.map { entry -> Manifest in
                    Manifest(path: manifestPath, outputDir: outputDir, manifestFile: entry)
                }
                manifests.append(contentsOf: additionalManifests)
            case .failure(let error):
                print(error)
                return
            }
        }

        print("Read \(manifests.count) configuration(s) from \(inputPaths.count) manifest file(s).")

        for idx in 0..<manifests.count {
            do {
                try validate(manifest: manifests[idx])
                if manifests[idx].configuration.srcDirPath.count > 0 {
                    try collectFiles(manifest: &manifests[idx], group: .general)
                }
                if manifests[idx].configuration.ovalSrcDirPath.count > 0 {
                    try collectFiles(manifest: &manifests[idx], group: .oval)
                }
                if manifests[idx].configuration.squareSrcDirPath.count > 0 {
                    try collectFiles(manifest: &manifests[idx], group: .square)
                }
                manifest = manifests[idx]
                process()
            } catch {
                print(error.localizedDescription)
            }
        }

        print("Done.")
    }

    func collectFiles(manifest: inout Manifest, group: SourceFileGroup) throws {
        let pathKey: WritableKeyPath<Configuation, String>
        let filesKey: WritableKeyPath<Manifest, [String]>

        switch group {
        case .general:
            pathKey = \Configuation.srcDirPath
            filesKey = \Manifest.files
        case .oval:
            pathKey = \Configuation.ovalSrcDirPath
            filesKey = \Manifest.ovalFiles
        case .square:
            pathKey = \Configuation.squareSrcDirPath
            filesKey = \Manifest.squareFiles
        }

        var cfg = manifest.configuration

        var files: [String] = []

        var isDirectory = ObjCBool(false)
        if FileManager.default.fileExists(atPath: cfg[keyPath: pathKey], isDirectory: &isDirectory) == true {
            if isDirectory.boolValue == true {
                files = try FileManager.default.contentsOfDirectory(atPath: cfg[keyPath: pathKey])
                files.sort()
            } else {
                files.append(cfg[keyPath: pathKey].lastPathComponent)
                cfg[keyPath: pathKey] = cfg[keyPath: pathKey].deletingLastPathComponent
            }
            files = cfg.filterByExtension(files: files)

            if manifest[keyPath: filesKey].count == 0 {
                manifest[keyPath: filesKey].append(contentsOf: files)
                return
            }

            let filtered = manifest[keyPath: filesKey].filter { (item: String) -> Bool in
                if files.contains(item) {
                    return true
                }
                return false
            }

            if filtered.count != manifest[keyPath: filesKey].count {
                throw ProcessError.collectFiles("Src is missing files listed in manifest.")
            }
        } else {
            throw ProcessError.collectFiles("Src does not exist. [\(cfg[keyPath: pathKey])]")
        }
    }

    func validate(manifest: Manifest) throws {
        let cfg = manifest.configuration

        if cfg.srcDirPath == "", cfg.ovalSrcDirPath == "" || cfg.squareSrcDirPath == "" {
            cfg.valid = false
            cfg.error = "Missing src."
            throw ProcessError.validate(cfg.error ?? "")
        }

        if cfg.dstDirPath == "" {
            cfg.valid = false
            cfg.error = "Missing dst."
            throw ProcessError.validate(cfg.error ?? "")
        }

        if cfg.scale != 0 {
            if cfg.maxWidth != 0 || cfg.maxHeight != 0 {
                cfg.valid = false
                cfg.error = "Can not specify scale and max-width / max-height."
                throw ProcessError.validate(cfg.error ?? "")
            }
        }
    }

    func clearStickerPack(folder: String) {
        let fm = FileManager.default
        do {
            let url = URL(fileURLWithPath: folder.appendingPathComponent("Contents.json"))
            let contents = try StickerPackContents.read(contentsOf: url).get()
            for item in contents.stickers {
                let itemPath = folder.appendingPathComponent(item.filename)
                try fm.removeItem(atPath: itemPath)
            }
            contents.stickers.removeAll()
            _ = try contents.write(to: url, pretty: true).get()
        } catch {
            print("Error in clearStickerPack: \(error)")
        }
    }

    func clearSplitCatalogs(folder: String) {
        var idx = 0
        while true {
            let path = "\(folder)_\(idx)"
            if FileManager.default.fileExists(atPath: path) == true {
                try? FileManager.default.removeItem(atPath: path)
                idx += 1
            } else {
                return
            }
        }
    }

    func clearCatalog(folder: String, isFolder: Bool = false) {
        clear(folder: folder)

        do {
            let contents = CatalogContents()
            contents.info.author = "xcode"
            contents.info.version = 1
            contents.isFolder = isFolder
            contents.properties.providesNamespace = manifest.configuration.catalogFolderNamespace
            if let tag = manifest.configuration.catalogFolderTag {
                if catalogFolderSegmentMaxSize != 0 {
                    contents.properties.onDemandResourceTags.append("\(tag)_\(catalogFolderSegmentIndex)")
                } else {
                    contents.properties.onDemandResourceTags.append(tag)
                }
            }
            let url = URL(fileURLWithPath: folder.appendingPathComponent("Contents.json"))
            _ = try contents.write(to: url, pretty: true).get()
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

    func setupCatalogFolderSegment() {
        catalogFolderSegmentPath = "\(catalogFolderSegmentBasePath)_\(catalogFolderSegmentIndex)"
        try? FileManager.default.createDirectory(atPath: catalogFolderSegmentPath, withIntermediateDirectories: true, attributes: nil)
        clearCatalog(folder: catalogFolderSegmentPath, isFolder: true)
    }

    func advanceSegmentIfNeeded() {
        if manifest.configuration.catalogFolderMaxSize != 0 {
            if catalogFolderSegmentAccumulatedSize > catalogFolderSegmentMaxSize {
                catalogFolderSegmentIndex += 1
                catalogFolderSegmentAccumulatedSize = 0
                setupCatalogFolderSegment()
            }
        }
    }

    // swiftlint:disable cyclomatic_complexity

    func process() {
        let cfg = manifest.configuration
        let package = cfg.outputPackage

        catalogFolderSegmentMaxSize = 0
        catalogFolderSegmentPath = cfg.dstDirPath

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
            if cfg.dstDirPath.hasSuffix(".iconset") == false, cfg.dstDirPath.hasSuffix(".appiconset") == false, cfg.dstDirPath.hasSuffix(".stickersiconset") == false {
                print("\(cfg.dstDirPath) is not a .iconset, .appiconset, or .stickersiconset directory.")
                return
            }
            if manifest.files.count != 1, manifest.ovalFiles.count == 0, manifest.squareFiles.count == 0 {
                print("Only 1 source image allowed when using iconset package. Found \(manifest.files.count).")
                return
            }
            if manifest.files.count == 0, manifest.ovalFiles.count != 1 || manifest.squareFiles.count != 1 {
                print("Only 1 source image allowed when using iconset package. Found \(manifest.ovalFiles.count)/\(manifest.squareFiles.count).")
                return
            }

        case .icns:
            if cfg.dstDirPath.hasSuffix(".icns") == false {
                print("\(cfg.dstDirPath) is not a .icns file.")
                return
            }
            if manifest.files.count != 1 {
                print("Only 1 source image allowed when using icns package. Found \(manifest.files.count).")
                return
            }
        case .catalog:
            if cfg.dstDirPath.hasSuffix(".xcassets") == false {
                print("\(cfg.dstDirPath) is not a .xcassets directory.")
                return
            }
            try? FileManager.default.createDirectory(atPath: cfg.dstDirPath, withIntermediateDirectories: true, attributes: nil)
            if cfg.outPackageReplace == true {
                clearCatalog(folder: cfg.dstDirPath)
            }
        case .catalogFolder:
            let assetParts = cfg.dstDirPath.components(separatedBy: "/").filter { component -> Bool in
                if component.hasSuffix(".xcassets") == true {
                    return true
                }
                return false
            }
            if assetParts.count == 0 {
                print("\(cfg.dstDirPath) is not in a .xcassets directory.")
                return
            }
            if cfg.catalogFolderMaxSize != 0 {
                catalogFolderSegmentIndex = 0
                catalogFolderSegmentMaxSize = cfg.catalogFolderMaxSize
                catalogFolderSegmentAccumulatedSize = 0
                catalogFolderSegmentBasePath = cfg.dstDirPath
                if cfg.outPackageReplace == true {
                    clearSplitCatalogs(folder: catalogFolderSegmentBasePath)
                }
                setupCatalogFolderSegment()
            } else {
                try? FileManager.default.createDirectory(atPath: cfg.dstDirPath, withIntermediateDirectories: true, attributes: nil)
                if cfg.outPackageReplace == true {
                    clearCatalog(folder: cfg.dstDirPath, isFolder: true)
                }
            }
        }

        print("Processing \(manifest.files.count) image(s)...")

        var outManifest: [String] = []
        var contactImages: [CGImage]?

        if cfg.outContactSheetPath != nil {
            contactImages = []
        }

        if manifest.ovalFiles.count == manifest.squareFiles.count, manifest.ovalFiles.count != 0 {
            for idx in 0..<manifest.ovalFiles.count {
                let ovalPath = cfg.ovalSrcDirPath.appendingPathComponent(manifest.ovalFiles[idx])
                let squarePath = cfg.squareSrcDirPath.appendingPathComponent(manifest.squareFiles[idx])
                advanceSegmentIfNeeded()
                processImage(srcImagePath: squarePath, ovalSrcImagePath: ovalPath, contactImages: &contactImages)

                var name = squarePath.lastPathComponent.changeFileExtension(to: "")
                name = name.changeFileSuffix(from: "@2x", to: "")
                name = name.changeFileSuffix(from: "@3x", to: "")
                outManifest.append(name)
            }
        } else {
            for file in manifest.files {
                let path = cfg.srcDirPath.appendingPathComponent(file)
                advanceSegmentIfNeeded()
                processImage(srcImagePath: path, contactImages: &contactImages)

                var name = path.lastPathComponent.changeFileExtension(to: "")
                name = name.changeFileSuffix(from: "@2x", to: "")
                name = name.changeFileSuffix(from: "@3x", to: "")
                outManifest.append(name)
            }
        }

        if let path = cfg.outContactSheetPath, let images = contactImages {
            makeContactSheet(images: images, path: path)
        }

        if let path = cfg.outManifestPath {
            do {
                let data = try JSONSerialization.data(withJSONObject: outManifest, options: [.prettyPrinted])
                try data.write(to: URL(fileURLWithPath: path))
            } catch {
                print("Error writing out manifest: \(error)")
            }
        }
    }

    func makeContactSheet(images: [CGImage], path: String) {
        // compute layout and size
        let count: Int = images.count
        var xCount = Int(sqrt(Double(count) * 2.0 / 3.0).rounded(.up))
        let width = max(xCount * 160, 640)
        xCount = width / 160
        let yCount = Int((Double(count) / Double(xCount)).rounded(.up))
        let height = max(yCount * 160, 920)

        let fullRect = CGRect(x: 0, y: 0, width: width, height: height)

        let bytesPerRow = width * 4
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: UInt32(bitmapInfo.rawValue)) else {
            print("Can't create CGContext. width: \(width), height: \(height), bytes per row: \(bytesPerRow)")
            return
        }

        context.clear(fullRect)
        context.setFillColor(NSColor(calibratedWhite: 55.0 / 255.0, alpha: 1.0).cgColor)
        context.fill(fullRect)

        for idx in 0..<count {
            let image = images[idx]
            let xOffset = (idx % xCount) * 160
            let yOffset = height - 160 - (((idx - (idx % xCount)) / xCount) * 160)
            var srcRect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
            var dstRect = CGRect(x: xOffset, y: yOffset, width: 160, height: 160)
            srcRect = aspectFit(src: srcRect, dst: &dstRect)

            context.draw(image, in: srcRect)
        }

        if let contactImage = context.makeImage() {
            write(image: contactImage, path: path)
        }
    }

    // swiftlint:enable cyclomatic_complexity

    func aspectFit(src: CGSize, dst: inout CGSize) -> CGSize {
        var nW = dst.width
        var nH = (src.height / src.width * nW).rounded(.down)

        if nH > dst.height {
            nH = dst.height
            nW = (src.width / src.height * nH).rounded(.down)
        }

        dst.width = nW
        dst.height = nH

        return dst
    }

    func aspectFit(src: CGRect, dst: inout CGRect) -> CGRect {
        var nW = dst.width
        var nH = (src.height / src.width * nW).rounded(.down)

        if nH > dst.height {
            nH = dst.height
            nW = (src.width / src.height * nH).rounded(.down)
        }

        dst.origin.x += ((dst.size.width - nW) / 2.0).rounded(.down)
        dst.origin.y += ((dst.size.height - nH) / 2.0).rounded(.down)
        dst.size.width = nW
        dst.size.height = nH

        return dst
    }

    func fill(src: CGRect, dst: CGRect) -> CGRect {
        var nW = dst.width
        var nH = (src.height / src.width * nW).rounded(.down)

        if nH < dst.height {
            nH = dst.height
            nW = (src.width / src.height * nH).rounded(.down)
        }

        var newSrc = CGRect(x: 0, y: 0, width: nW, height: nH)
        if newSrc.width > dst.width {
            newSrc.origin.x = ((dst.width - newSrc.width) / 2.0).rounded(.towardZero)
        } else if newSrc.height > dst.height {
            newSrc.origin.y = ((dst.height - newSrc.height) / 2.0).rounded(.towardZero)
        }

        return newSrc
    }

    func scale(image: CGImage, width: Int, height: Int, scaleMode: ScaleMode = .aspectFit, processMode: ProcessMode = .normal, srcPadPercent: Double = 0) -> CGImage? {
        var srcRect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        var dstRect = CGRect(x: 0, y: 0, width: width, height: height)
        if srcPadPercent != 0.0 {
            var dw = Double(width) * srcPadPercent
            var dh = Double(height) * srcPadPercent
            if dw > dh {
                dh = dw * Double(height) / Double(width)
            } else {
                dw = dh * Double(width) / Double(height)
            }
            dstRect = dstRect.insetBy(dx: CGFloat(dw).rounded(.down), dy: CGFloat(dh).rounded(.down))
        }
        let fullRect = dstRect

        switch scaleMode {
        case .aspectFit:
            srcRect = aspectFit(src: srcRect, dst: &dstRect)
        case .fill:
            srcRect = fill(src: srcRect, dst: dstRect)
        }

        switch processMode {
        case .normal:
            let bytesPerRow = width * 4
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
            guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: UInt32(bitmapInfo.rawValue)) else {
                print("Can't create CGContext. width: \(width), height: \(height), bytes per row: \(bytesPerRow)")
                return nil
            }

            context.clear(fullRect)
            if let color = manifest.configuration.backgroundColor {
                context.setFillColor(color.nsColor.cgColor)
                context.fill(fullRect)
            }
            context.draw(image, in: srcRect)
            return context.makeImage()
        case .mask:
            let colorSpace = CGColorSpaceCreateDeviceGray()
            let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
            guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: UInt32(bitmapInfo.rawValue)) else {
                print("Can't create CGContext. width: \(width), height: \(height)")
                return nil
            }

            context.clear(fullRect)
            context.setFillColor(gray: 1.0, alpha: 1.0)
            context.fill(fullRect)
            context.setBlendMode(.destinationAtop)
            context.draw(image, in: srcRect)
            context.setBlendMode(.normal)
            context.setFillColor(gray: 0.0, alpha: 1.0)
            for rect in fullRect.simpleRemainer(usedArea: srcRect) {
                context.fill(rect)
            }
            return context.makeImage()
        }
    }

    func setStickerPackSize(_ path: String, size: String) {
        do {
            let url = URL(fileURLWithPath: path.appendingPathComponent("Contents.json"))
            let contents = try StickerPackContents.read(contentsOf: url).get()
            contents.properties.gridSize = size
            _ = try contents.write(to: url, pretty: true).get()
        } catch {
            print("Error in setStickerPackSize: \(error)")
        }
    }

    func insertStickerToPack(_ path: String) -> String {
        do {
            let fm = FileManager.default
            let contentsPath = path.deletingLastPathComponent.appendingPathComponent("Contents.json")
            let contents = try StickerPackContents.read(contentsOf: URL(fileURLWithPath: contentsPath)).get()

            let stickerDirPath = path.changeFileExtension(to: "sticker")
            let stickerContentsPath = stickerDirPath.appendingPathComponent("Contents.json")
            let stickerImagePath = stickerDirPath.appendingPathComponent(path.lastPathComponent)

            try fm.createDirectory(atPath: stickerDirPath, withIntermediateDirectories: true)

            let stickerContents = StickerContents()
            stickerContents.info.author = "xcode"
            stickerContents.info.version = 1
            stickerContents.properties.filename = path.lastPathComponent
            _ = try stickerContents.write(to: URL(fileURLWithPath: stickerContentsPath), pretty: true).get()

            let newSticker = StickerPackContentsSticker()
            newSticker.filename = path.lastPathComponent.changeFileExtension(to: "sticker")
            contents.stickers.append(newSticker)

            _ = try contents.write(to: URL(fileURLWithPath: contentsPath), pretty: true).get()

            return stickerImagePath
        } catch {
            print("Error in insertStickerToPack: \(error)")
        }

        return ""
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

        if fm.fileExists(atPath: setPath) == true {
            do {
                try fm.removeItem(atPath: setPath)
            } catch {
                print("Error deleting \(setPath): \(error)")
            }
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
            _ = try contents.write(to: URL(fileURLWithPath: setPath.appendingPathComponent("Contents.json")), pretty: true).get()
        } catch {
            print("Error in clearImageSet: \(error)")
        }
    }

    func insertImageToSet(_ path: String) -> String {
        do {
            let setPath = imageSetPathFromImagePath(path)
            let url = URL(fileURLWithPath: setPath.appendingPathComponent("Contents.json"))
            let contents = try ImageSetContents.read(contentsOf: url).get()

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

            contents.images.append(imageRecord)

            _ = try contents.write(to: url, pretty: true).get()

            return setPath.appendingPathComponent(newFileName)
        } catch {
            print("Error in insertImageToSet: \(error)")
        }
        return ""
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

    func processIconSet(srcImagePath: String, ovalSrcImagePath: String?, plan: Plan) {
        let dstFolderPath = catalogFolderSegmentPath

        do {
            let url = URL(fileURLWithPath: dstFolderPath.appendingPathComponent("Contents.json"))
            let contents = try ImageSetContents.read(contentsOf: url).get()

            for image in contents.images {
                let neededSize = image.size
                let neededScale = image.scale
                let currentFilename = image.filename

                if neededSize == nil {
                    print("Missing size.")
                    return
                }
                if neededScale == nil {
                    print("Missing scale.")
                    return
                }

                let sizeParts = neededSize?.components(separatedBy: "x") ?? ["1"]
                let scaleParts = neededScale?.components(separatedBy: "x") ?? ["1", "1"]

                let reqScale = Double(scaleParts[0]) ?? 0.0
                let reqWidth = Double(sizeParts[0]) ?? 0.0
                let reqHeight = Double(sizeParts[1]) ?? 0.0

                let neededWidth = Int(reqWidth * reqScale)
                let neededHeight = Int(reqHeight * reqScale)

                if let currentFilename = currentFilename {
                    let path = dstFolderPath.appendingPathComponent(currentFilename)
                    do {
                        try FileManager.default.removeItem(atPath: path)
                        image.filename = ""
                    } catch {
                        print("Error deleting \(path): \(error)")
                    }
                }

                var theSrcImagePath = srcImagePath
                if let ovalSrcImagePath = ovalSrcImagePath, reqWidth != reqHeight {
                    theSrcImagePath = ovalSrcImagePath
                }

                if let reqSuffix = plan.requiredSuffix, theSrcImagePath.hasFileSuffix(reqSuffix) == false {
                    print("\(theSrcImagePath) does not have the required suffix: \(reqSuffix)")
                    continue
                }

                var dstName = theSrcImagePath.lastPathComponent
                if ImageFormat.formatForPath(dstName) == .unchanged {
                    print("\(theSrcImagePath) has an unsupported source format.")
                    continue
                }
                if plan.outputFormat != .unchanged {
                    dstName = dstName.changeFileExtension(from: dstName.pathExtension, to: plan.outputFormat.rawValue)
                }

                let newSuffix = "-\(neededSize!)-\(neededScale!)"
                dstName = dstName.changeFileSuffix(from: "", to: newSuffix)

                let dstPath = dstFolderPath.appendingPathComponent(dstName)

                let srcImageUrl = URL(fileURLWithPath: theSrcImagePath)
                let srcImageSource = CGImageSourceCreateWithURL(srcImageUrl as CFURL, nil)
                var srcImage: CGImage?
                if let srcImageSource = srcImageSource {
                    srcImage = CGImageSourceCreateImageAtIndex(srcImageSource, 0, nil)
                }

                if srcImage == nil {
                    print("Failed to load image \(theSrcImagePath).")
                    continue
                }

                var dstImage: CGImage?

                if let srcImage = srcImage {
                    dstImage = scale(image: srcImage, width: neededWidth, height: neededHeight, scaleMode: .fill)
                }

                if let image = dstImage {
                    write(image: image, path: dstPath)
                } else if let image = srcImage {
                    write(image: image, path: dstPath)
                }

                image.filename = dstName
            }

            _ = try contents.write(to: url, pretty: true).get()
        } catch {
            print("Error in processIconSet: \(error)")
        }
    }

    func processGenericIconSet(srcImagePath: String, plan: Plan) {
        let dstFolderPath = catalogFolderSegmentPath

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

            if let reqSuffix = plan.requiredSuffix, srcImagePath.hasFileSuffix(reqSuffix) == false {
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

            var newSuffix = "\(onePlan.boxWidth)x\(onePlan.boxHeight)"
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
                dstImage = scale(image: srcImage, width: neededWidth, height: neededHeight, scaleMode: .fill)
            }

            if let image = dstImage {
                write(image: image, path: dstPath)
            } else if let image = srcImage {
                write(image: image, path: dstPath)
            }
        }
    }

    // swiftlint:enable cyclomatic_complexity

    func processIcns(srcImagePath: String, plan: Plan) {
        let dstFilePath = catalogFolderSegmentPath
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

            if let reqSuffix = plan.requiredSuffix, srcImagePath.hasFileSuffix(reqSuffix) == false {
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
                dstImage = scale(image: srcImage, width: neededWidth, height: neededHeight, scaleMode: .fill)
            }

            if let image = dstImage {
                write(image: image, path: dstPath)
            } else if let image = srcImage {
                write(image: image, path: dstPath)
            }
        }

        ProcessRunner.runCommand("iconutil", args: ["--convert", "icns", "--output", dstFilePath, dstFolderPath])

        do {
            try FileManager.default.removeItem(atPath: dstFolderPath)
        } catch {
            print("Error deleting \(dstFolderPath): \(error)")
        }
    }

    // swiftlint:disable cyclomatic_complexity

    func processImage(srcImagePath: String, ovalSrcImagePath: String? = nil, contactImages: inout [CGImage]?) {
        print("Processing: \(srcImagePath.lastPathComponent)")

        var modes: [ProcessMode] = [.normal]
        if manifest.configuration.masksToo == true {
            modes.append(.mask)
        }

        var contactImageStored = false
        for mode in modes {
            var oneTimeDone = false
            var maxFileSize = 0

            for plan in manifest.configuration.plans {
                var srcPadPercent: Double = 0
                var sizePassed = false
                repeat {
                    switch manifest.configuration.outputPackage {
                    case .none:
                        break
                    case .stickerPack:
                        break
                    case .imageSet:
                        break
                    case .iconSet:
                        if manifest.configuration.dstDirPath.hasSuffix(".iconset") {
                            processGenericIconSet(srcImagePath: srcImagePath, plan: plan)
                        } else {
                            processIconSet(srcImagePath: srcImagePath, ovalSrcImagePath: ovalSrcImagePath, plan: plan)
                        }
                        sizePassed = true
                        continue
                    case .icns:
                        processIcns(srcImagePath: srcImagePath, plan: plan)
                        sizePassed = true
                        continue
                    case .catalog:
                        break
                    case .catalogFolder:
                        break
                    }

                    if let reqSuffix = plan.requiredSuffix, srcImagePath.hasFileSuffix(reqSuffix) == false {
                        print("\(srcImagePath) does not have the required suffix: \(reqSuffix)")
                        continue
                    }

                    var dstName = srcImagePath.lastPathComponent
                    if mode == .mask {
                        dstName = dstName.changeFileSuffix(from: "", to: "_mask")
                    }
                    let dstFormat = ImageFormat.formatForPath(dstName)
                    if dstFormat == .unchanged {
                        print("\(srcImagePath) has an unsupported source format.")
                        continue
                    }
                    if plan.outputFormat != .unchanged {
                        dstName = dstName.changeFileExtension(from: dstName.pathExtension, to: plan.outputFormat.rawValue)
                    }
                    if mode == .mask {
                        dstName = dstName.changeFileExtension(from: dstName.pathExtension, to: ImageFormat.PNG.rawValue)
                    }

                    var dstPath = catalogFolderSegmentPath.appendingPathComponent(dstName)

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
                    var newWidth = 0
                    var newHeight = 0

                    if let srcImage = srcImage {
                        if plan.scale != 0 {
                            if plan.scale != 1 {
                                newWidth = Int((Double(srcImage.width) * plan.scale).rounded(.down))
                                newHeight = Int((Double(srcImage.height) * plan.scale).rounded(.down))
                            }
                        } else {
                            if plan.boxWidth == 0, plan.boxHeight == 0 {
                                // no action
                            } else {
                                if plan.boxWidth == 0 {
                                    newWidth = plan.boxHeight
                                    newHeight = plan.boxHeight
                                } else if plan.boxHeight == 0 {
                                    newWidth = plan.boxWidth
                                    newHeight = plan.boxWidth
                                } else {
                                    newWidth = plan.boxWidth
                                    newHeight = plan.boxHeight
                                }
                                if plan.aspectWithMaxBox == true {
                                    var dstSize: CGSize = .init(width: newWidth, height: newHeight)
                                    let fit = aspectFit(src: CGSize(width: srcImage.width, height: srcImage.height), dst: &dstSize)
                                    newWidth = Int(fit.width)
                                    newHeight = Int(fit.height)
                                }
                            }
                        }
                        if newWidth != 0, newHeight != 0 {
                            dstImage = scale(image: srcImage, width: newWidth, height: newHeight, processMode: mode, srcPadPercent: srcPadPercent)
                        }
                    }

                    switch manifest.configuration.outputPackage {
                    case .none:
                        break
                    case .stickerPack:
                        dstPath = insertStickerToPack(dstPath)
                    case .imageSet, .catalog, .catalogFolder:
                        if oneTimeDone == false {
                            clearImageSet(dstPath)
                            oneTimeDone = true
                        }
                        dstPath = insertImageToSet(dstPath)
                    case .iconSet:
                        break
                    case .icns:
                        break
                    }

                    if let image = dstImage {
                        write(image: image, path: dstPath)
                        if contactImageStored == false {
                            contactImages?.append(image)
                        }
                        contactImageStored = true
                    } else if let image = srcImage {
                        write(image: image, path: dstPath)
                        if contactImageStored == false {
                            contactImages?.append(image)
                        }
                        contactImageStored = true
                    }

                    let fileSize = getSize(of: URL(fileURLWithPath: dstPath))

                    if manifest.configuration.outputPackage == .stickerPack, fileSize > 500000 {
                        srcPadPercent += 0.01
                        print("\(dstPath.lastPathComponent) is too large (> 500,000 bytes) at size \(fileSize) ... adding padding")
                        if srcPadPercent > 0.5 {
                            sizePassed = true
                        }
                    } else {
                        sizePassed = true
                    }

                    if fileSize > maxFileSize {
                        maxFileSize = fileSize
                    }
                } while sizePassed == false
            }

            catalogFolderSegmentAccumulatedSize += maxFileSize
        }
    }

    // swiftlint:enable cyclomatic_complexity

    func getSize(of url: URL) -> Int {
        var fileSize = 0

        let keys: Set<URLResourceKey> = [URLResourceKey.fileSizeKey]
        do {
            let resourceValues = try url.resourceValues(forKeys: keys)
            if let value = resourceValues.fileSize {
                fileSize += value
            }
        } catch {
            print("\(error)")
        }
        return fileSize
    }
}
