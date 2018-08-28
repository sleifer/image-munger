//
//  Plan.swift
//  image-munger
//
//  Created by Simeon Leifer on 8/29/18.
//  Copyright © 2018 droolingcat.com. All rights reserved.
//

import Foundation

class Plan {
    var scale: Double
    var boxWidth: Int
    var boxHeight: Int
    var outputFormat: ImageFormat
    var outputPackage: PackageType
    var requiredSuffix: String?
    var removeSuffix: String?
    var addSuffix: String?

    init() {
        scale = 0.0
        boxWidth = 0
        boxHeight = 0
        outputFormat = .unchanged
        outputPackage = .none
    }

    init(scale: Double = 0.0, boxWidth: Int = 0, boxHeight: Int = 0, outputFormat: ImageFormat = .unchanged, outputPackage: PackageType = .none, requiredSuffix: String? = nil, removeSuffix: String? = nil, addSuffix: String? = nil) {
        self.scale = scale
        self.boxWidth = boxWidth
        self.boxHeight = boxHeight
        self.outputFormat = outputFormat
        self.outputPackage = outputPackage
        self.requiredSuffix = requiredSuffix
        self.removeSuffix = removeSuffix
        self.addSuffix = addSuffix
    }
}
