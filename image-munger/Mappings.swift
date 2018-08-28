//
//  Mappings.swift
//  image-munger
//
//  Created by Simeon Leifer on 8/31/18.
//  Copyright © 2018 droolingcat.com. All rights reserved.
//

import Foundation

class StickerPackContents: Mappable {
    var stickers: [StickerPackContentsSticker] = []
    var info: StickerPackContentsInfo = StickerPackContentsInfo()
    var properties: StickerPackContentsProperties = StickerPackContentsProperties()

    init() {
    }

    required init?(map: Map) {
    }

    func mapping(map: Map) {
        stickers <- map["stickers"]
        info <- map["info"]
        properties <- map["properties"]
    }
}

class StickerPackContentsSticker: Mappable {
    var filename: String = ""

    init() {
    }

    required init?(map: Map) {
    }

    func mapping(map: Map) {
        filename <- map["filename"]
    }
}

class StickerPackContentsInfo: Mappable {
    var version: Int = 0
    var author: String = ""

    init() {
    }

    required init?(map: Map) {
    }

    func mapping(map: Map) {
        version <- map["version"]
        author <- map["author"]
    }
}

class StickerPackContentsProperties: Mappable {
    var gridSize: String = ""

    init() {
    }

    required init?(map: Map) {
    }

    func mapping(map: Map) {
        gridSize <- map["grid-size"]
    }
}

class StickerContents: Mappable {
    var info: StickerContentsInfo = StickerContentsInfo()
    var properties: StickerContentsProperties = StickerContentsProperties()

    init() {
    }

    required init?(map: Map) {
    }

    func mapping(map: Map) {
        info <- map["info"]
        properties <- map["properties"]
    }
}

class StickerContentsInfo: Mappable {
    var version: Int = 0
    var author: String = ""

    init() {
    }

    required init?(map: Map) {
    }

    func mapping(map: Map) {
        version <- map["version"]
        author <- map["author"]
    }
}

class StickerContentsProperties: Mappable {
    var filename: String = ""

    init() {
    }

    required init?(map: Map) {
    }

    func mapping(map: Map) {
        filename <- map["filename"]
    }
}

class CatalogContents: Mappable {
    var info: CatalogContentsInfo = CatalogContentsInfo()

    init() {
    }

    required init?(map: Map) {
    }

    func mapping(map: Map) {
        info <- map["info"]
    }
}

class CatalogContentsInfo: Mappable {
    var version: Int = 0
    var author: String = ""

    init() {
    }

    required init?(map: Map) {
    }

    func mapping(map: Map) {
        version <- map["version"]
        author <- map["author"]
    }
}

class ImageSetContents: Mappable {
    var images: [ImageSetContentsImage] = []
    var info: ImageSetContentsInfo = ImageSetContentsInfo()

    init() {
    }

    required init?(map: Map) {
    }

    func mapping(map: Map) {
        images <- map["images"]
        info <- map["info"]
    }
}

class ImageSetContentsImage: Mappable {
    var filename: String = ""
    var idiom: String = ""
    var scale: String = ""
    var platform: String = ""
    var size: String = ""

    init() {
    }

    required init?(map: Map) {
    }

    func mapping(map: Map) {
        filename <- map["filename", ignoreNil: true]
        idiom <- map["idiom", ignoreNil: true]
        scale <- map["scale", ignoreNil: true]
        platform <- map["platform", ignoreNil: true]
        size <- map["size", ignoreNil: true]
    }
}

class ImageSetContentsInfo: Mappable {
    var version: Int = 0
    var author: String = ""

    init() {
    }

    required init?(map: Map) {
    }

    func mapping(map: Map) {
        version <- map["version"]
        author <- map["author"]
    }
}
