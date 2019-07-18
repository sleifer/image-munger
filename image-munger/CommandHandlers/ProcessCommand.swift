//
//  ProcessCommand.swift
//  image-munger
//
//  Created by Simeon Leifer on 8/25/18.
//  Copyright © 2018 droolingcat.com. All rights reserved.
//

import Foundation
import CommandLineCore

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

enum SourceFileGroup {
    case general
    case oval
    case square
}

enum ScaleMode {
    case aspectFit
    case fill
}

class ProcessCommand: Command {
    var manifest: Manifest = Manifest()
    var catalogFolderSegmentMaxSize: Int = 0
    var catalogFolderSegmentIndex: Int = 0
    var catalogFolderSegmentAccumulatedSize: Int = 0
    var catalogFolderSegmentBasePath: String = ""
    var catalogFolderSegmentPath: String = ""

    required init() {
    }

    func run(cmd: ParsedCommand, core: CommandCore) {
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
                self.manifest = manifests[idx]
                process()
            } catch {
                print(error.localizedDescription)
            }
        }

        print("Done.")
    }

    static func commandDefinition() -> SubcommandDefinition {
        var command = SubcommandDefinition()
        command.name = "process"
        command.synopsis = "Process images according to manifest file."
        command.hasFileParameters = true

        var output = CommandOption()
        output.shortOption = "-o"
        output.longOption = "--output"
        output.help = "Output directory"
        output.argumentCount = 1
        output.hasFileArguments = true
        command.options.append(output)

        var parameter = ParameterInfo()
        parameter.help = "manifest file"
        command.requiredParameters.append(parameter)

        return command
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

        if cfg.srcDirPath == "" && (cfg.ovalSrcDirPath == "" || cfg.squareSrcDirPath == "") {
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

    func clearSplitCatalogs(folder: String) {
        var idx: Int = 0
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
            if cfg.dstDirPath.hasSuffix(".appiconset") == false && cfg.dstDirPath.hasSuffix(".stickersiconset") == false {
                print("\(cfg.dstDirPath) is not a .appiconset or .stickersiconset directory.")
                return
            }
            if manifest.files.count != 1 && manifest.ovalFiles.count == 0 && manifest.squareFiles.count == 0 {
                print("Only 1 source image allowed when using iconset package. Found \(manifest.files.count).")
                return
            }
            if manifest.files.count == 0 && (manifest.ovalFiles.count != 1 || manifest.squareFiles.count != 1) {
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
            let assetParts = cfg.dstDirPath.components(separatedBy: "/").filter { (component) -> Bool in
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

        if manifest.ovalFiles.count == manifest.squareFiles.count && manifest.ovalFiles.count != 0 {
            for idx in 0..<manifest.ovalFiles.count {
                let ovalPath = cfg.ovalSrcDirPath.appendingPathComponent(manifest.ovalFiles[idx])
                let squarePath = cfg.squareSrcDirPath.appendingPathComponent(manifest.squareFiles[idx])
                advanceSegmentIfNeeded()
                processImage(srcImagePath: squarePath, ovalSrcImagePath: ovalPath)

                var name = squarePath.lastPathComponent.changeFileExtension(to: "")
                name = name.changeFileSuffix(from: "@2x", to: "")
                name = name.changeFileSuffix(from: "@3x", to: "")
                outManifest.append(name)
            }
        } else {
            for file in manifest.files {
                let path = cfg.srcDirPath.appendingPathComponent(file)
                advanceSegmentIfNeeded()
                processImage(srcImagePath: path)

                var name = path.lastPathComponent.changeFileExtension(to: "")
                name = name.changeFileSuffix(from: "@2x", to: "")
                name = name.changeFileSuffix(from: "@3x", to: "")
                outManifest.append(name)
            }
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

        dst.origin.x = ((dst.size.width - nW) / 2.0).rounded(.down)
        dst.origin.y = ((dst.size.height - nH) / 2.0).rounded(.down)
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

    func scale(image: CGImage, width: Int, height: Int, mode: ScaleMode = .aspectFit) -> CGImage? {
        var srcRect = CGRect(x: 0, y: 0, width: image.width, height: image.height)
        var dstRect = CGRect(x: 0, y: 0, width: width, height: height)
        let fullRect = dstRect

        switch mode {
        case .aspectFit:
            srcRect = aspectFit(src: srcRect, dst: &dstRect)
        case .fill:
            srcRect = fill(src: srcRect, dst: dstRect)
        }

        let bytesPerRow = width * 4
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        guard let context = CGContext.init(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: UInt32(bitmapInfo.rawValue)) else {
            print("Can't create CGContext. width: \(width), height: \(height), bytes per row: \(bytesPerRow)")
            return nil
        }

        context.clear(fullRect)
        if let color = manifest.configuration.backgroundColor {
            context.setFillColor(color.cgColor)
            context.fill(fullRect)
        }
        context.draw(image, in: srcRect)
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

    func processIconSet(srcImagePath: String, ovalSrcImagePath: String?, plan: Plan) {
        let dstFolderPath = catalogFolderSegmentPath

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
                    dstImage = scale(image: srcImage, width: neededWidth, height: neededHeight, mode: .fill)
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
                dstImage = scale(image: srcImage, width: neededWidth, height: neededHeight, mode: .fill)
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

    func processImage(srcImagePath: String, ovalSrcImagePath: String? = nil) {
        print("Processing: \(srcImagePath.lastPathComponent)")

        var oneTimeDone: Bool = false
        var maxFileSize: Int = 0

        for plan in manifest.configuration.plans {

            switch manifest.configuration.outputPackage {
            case .none:
                break
            case .stickerPack:
                break
            case .imageSet:
                break
            case .iconSet:
                processIconSet(srcImagePath: srcImagePath, ovalSrcImagePath: ovalSrcImagePath, plan: plan)
                continue
            case .icns:
                processIcns(srcImagePath: srcImagePath, plan: plan)
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
            let dstFormat = ImageFormat.formatForPath(dstName)
            if dstFormat == .unchanged {
                print("\(srcImagePath) has an unsupported source format.")
                continue
            }
            if plan.outputFormat != .unchanged {
                dstName = dstName.changeFileExtension(from: dstName.pathExtension, to: plan.outputFormat.rawValue)
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
            var newWidth: Int = 0
            var newHeight: Int = 0

            if let srcImage = srcImage {
                if plan.scale != 0 {
                    if plan.scale != 1 {
                        newWidth = Int((Double(srcImage.width) * plan.scale).rounded(.down))
                        newHeight = Int((Double(srcImage.height) * plan.scale).rounded(.down))
                    }
                } else {
                    if plan.boxWidth == 0 && plan.boxHeight == 0 {
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
                            var dstSize: CGSize = CGSize(width: newWidth, height: newHeight)
                            let fit = aspectFit(src: CGSize(width: srcImage.width, height: srcImage.height), dst: &dstSize)
                            newWidth = Int(fit.width)
                            newHeight = Int(fit.height)
                        }
                    }
                }
                if newWidth != 0 && newHeight != 0 {
                    dstImage = scale(image: srcImage, width: newWidth, height: newHeight)
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
            } else if let image = srcImage {
                write(image: image, path: dstPath)
            }

            let fileSize = getSize(of: URL(fileURLWithPath: dstPath))
            if fileSize > maxFileSize {
                maxFileSize = fileSize
            }
        }

        catalogFolderSegmentAccumulatedSize += maxFileSize
    }

    // swiftlint:enable cyclomatic_complexity

    func getSize(of url: URL) -> Int {
        var fileSize: Int = 0

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
