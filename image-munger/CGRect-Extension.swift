//
//  CGRect-Extension.swift
//  image-munger
//
//  Created by Simeon Leifer on 7/20/19.
//  Copyright © 2019 droolingcat.com. All rights reserved.
//

import Foundation

extension CGRect {
    func simpleRemainer(usedArea: CGRect) -> [CGRect] {
        var remainders: [CGRect] = []
        if usedArea.minX > self.minX {
            let rect = self.divided(atDistance: usedArea.minX - self.minX, from: .minXEdge).slice
            remainders.append(rect)
        }
        if usedArea.maxX < self.maxX {
            let rect = self.divided(atDistance: self.maxX - usedArea.maxX, from: .maxXEdge).slice
            remainders.append(rect)
        }
        if usedArea.minY > self.minY {
            let rect = self.divided(atDistance: usedArea.minY - self.minY, from: .minYEdge).slice
            remainders.append(rect)
        }
        if usedArea.maxY < self.maxY {
            let rect = self.divided(atDistance: self.maxY - usedArea.maxY, from: .maxYEdge).slice
            remainders.append(rect)
        }
        return remainders
    }
}
