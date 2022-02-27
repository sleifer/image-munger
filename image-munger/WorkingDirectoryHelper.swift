//
//  WorkingDirectoryHelper.swift
//  image-munger
//
//  Created by Simeon Leifer on 2/27/22.
//

import Foundation

public struct WorkingDirectoryHelper {
    public private(set) var baseDirectory: String

    public init() {
        baseDirectory = FileManager.default.currentDirectoryPath
    }

    public func baseSubPath(_ subpath: String) -> String {
        var path = subpath.standardizingPath
        if path.isAbsolutePath == false {
            path = baseDirectory.appendingPathComponent(path)
        }
        return path
    }

    public func setCurrentDir(_ subpath: String) {
        FileManager.default.changeCurrentDirectoryPath(baseSubPath(subpath))
    }

    public func resetCurrentDir() {
        setCurrentDir(baseDirectory)
    }

    /// override the current working directory of the tool. Principally for testing.
    /// - Parameter path: path to set as `baseDirectory`
    public mutating func setBaseDir(_ path: String) {
        baseDirectory = path.fullPath
        FileManager.default.changeCurrentDirectoryPath(baseDirectory)
    }
}
