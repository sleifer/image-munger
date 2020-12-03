//
//  Mappings.swift
//  image-munger
//
//  Created by Simeon Leifer on 8/31/18.
//  Copyright © 2018 droolingcat.com. All rights reserved.
//

import Foundation

class StickerPackContents: Codable, JSONReadWrite {
    typealias HostClass = StickerPackContents

    var stickers: [StickerPackContentsSticker] = []
    var info: StickerPackContentsInfo = StickerPackContentsInfo()
    var properties: StickerPackContentsProperties = StickerPackContentsProperties()

    init() {}
}

class StickerPackContentsSticker: Codable {
    var filename: String = ""

    init() {}
}

class StickerPackContentsInfo: Codable {
    var version: Int = 0
    var author: String = ""

    init() {}
}

class StickerPackContentsProperties: Codable {
    var gridSize: String = ""

    init() {}

    enum CodingKeys: String, CodingKey {
        case gridSize = "grid-size"
    }
}

class StickerContents: Codable, JSONReadWrite {
    typealias HostClass = StickerContents

    var info: StickerContentsInfo = StickerContentsInfo()
    var properties: StickerContentsProperties = StickerContentsProperties()

    init() {}
}

class StickerContentsInfo: Codable {
    var version: Int = 0
    var author: String = ""

    init() {}
}

class StickerContentsProperties: Codable {
    var filename: String = ""

    init() {}
}

class CatalogContents: Codable, JSONReadWrite {
    typealias HostClass = CatalogContents

    var info: CatalogContentsInfo = CatalogContentsInfo()
    var properties: CatalogContentsProperties = CatalogContentsProperties()
    var isFolder: Bool = false

    init() {}

    enum CodingKeys: CodingKey {
        case info
        case properties
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        info = try container.decode(CatalogContentsInfo.self, forKey: .info)
        properties = try container.decodeIfPresent(CatalogContentsProperties.self, forKey: .properties) ?? CatalogContentsProperties()
        isFolder = container.contains(.properties)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(info, forKey: .info)
        if isFolder == true {
            try container.encode(properties, forKey: .properties)
        }
    }
}

class CatalogContentsInfo: Codable {
    var version: Int = 0
    var author: String = ""

    init() {}
}

class CatalogContentsProperties: Codable {
    var providesNamespace: Bool = false
    var onDemandResourceTags: [String] = []

    init() {}

    enum CodingKeys: String, CodingKey {
        case providesNamespace = "provides-namespace"
        case onDemandResourceTags = "on-demand-resource-tags"
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        providesNamespace = try container.decode(Bool.self, forKey: .providesNamespace)
        onDemandResourceTags = try container.decodeIfPresent([String].self, forKey: .onDemandResourceTags) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(providesNamespace, forKey: .providesNamespace)
        if onDemandResourceTags.count > 0 {
            try container.encode(onDemandResourceTags, forKey: .onDemandResourceTags)
        }
    }
}

class ImageSetContents: Codable, JSONReadWrite {
    typealias HostClass = ImageSetContents

    var images: [ImageSetContentsImage] = []
    var info: ImageSetContentsInfo = ImageSetContentsInfo()

    init() {}
}

class ImageSetContentsImage: Codable {
    var filename: String?
    var idiom: String?
    var scale: String?
    var platform: String?
    var size: String?
    var role: String?
    var subtype: String?

    init() {}
}

class ImageSetContentsInfo: Codable {
    var version: Int = 0
    var author: String = ""

    init() {}
}
