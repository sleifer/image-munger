//
//  ManifestFile.swift
//  image-munger
//
//  Created by Simeon Leifer on 5/3/20.
//  Copyright © 2020 droolingcat.com. All rights reserved.
//

import Foundation

class ManifestFile: YAMLReadWrite {
    typealias HostClass = ManifestFile

    var backgroundColor: String?
    var catalogFolderNamespace: String?
    var catalogFolderTag: String?
    var catalogFolderMaxSize: String?
    var dst: String?
    var files: [String]?
    var masksToo: String?
    var maxHeightPx: String?
    var maxPx: String?
    var maxWidthPx: String?
    var outContactSheet: String?
    var outFormat: String?
    var outManifest: String?
    var outPackage: String?
    var outPackageReplace: String?
    var preset: String?
    var scale: String?
    var src: String?
    var srcOval: String?
    var srcSquare: String?
    var validFormat: String?

    static func sample() -> ManifestFile {
        let sample = ManifestFile()

        sample.backgroundColor = "custom background color (0-255) red:green:blue or red:green:blue:alpha"
        sample.catalogFolderNamespace = "true | false"
        sample.catalogFolderTag = "catalog folder tag"
        sample.catalogFolderMaxSize = "maximum size of catalog folder in bytes"
        sample.dst = "directory to write images to"
        sample.files = ["ordered list of files to load, only listed files will be used instead of all if omitted"]
        sample.masksToo = "output images masks along side the images (true | false)"
        sample.maxHeightPx = "max output image height (fit in rectangle)"
        sample.maxPx = "max output image width or height (fit in square)"
        sample.maxWidthPx = "max output image width (fit in rectangle)"
        sample.outContactSheet = "output a contact sheet file at this path"
        sample.outFormat = "output image format (unchanged, jpg, png, gif, tif"
        sample.outManifest = "output a manifest file at this path"
        sample.outPackage = "output package format (none, stickerpack, imageset, iconset, icns, catalog, catalogfolder)"
        sample.outPackageReplace = "replace existing package contents (true | false)"
        sample.preset = "preset to use (none, smallSticker, mediumSticker, largeSticker, thumb256, imageSet, stickerImageSet1, stickerImageSet2, stickerImageSet3, stickerImageSet12, stickerImageSet13, stickerImageSet23, stickerImageSet123, stickerImageFiles1, stickerImageFiles2, stickerImageFiles3, stickerImageFiles12, stickerImageFiles13, stickerImageFiles23, stickerImageFiles123)"
        sample.scale = "image scale (1.0, 2.0, 3.0)"
        sample.src = "path to source folder; ~~/ == relative to manifest file directory; ~~~/ == relative to output directory (defaults to directory tool is run from)"
        sample.srcOval = "alternate to src for files meant to oval outputs"
        sample.srcSquare = "alternate to src for files meant to square outputs"
        sample.validFormat = "colon separated list of valid file extensions (without period); default is jpg:png:gif:tif"

        return sample
    }
}
