//
//  YAMLReadWrite.swift
//  TripWire
//
//  Created by Simeon Leifer on 1/20/20.
//  Copyright © 2020 droolingcat.com. All rights reserved.
//

import Foundation
import Yams

protocol YAMLReadWrite where Self: Codable {
    associatedtype HostClass: Codable

    static func read(contentsOf url: URL) -> Result<Self.HostClass, Error>
    func write(to url: URL) -> Result<Bool, Error>
}

enum YAMLReadWriteError: Error {
    case fileDoesNotExist
}

extension YAMLReadWrite {
    static func read(contentsOf url: URL) -> Result<Self.HostClass, Error> {
        do {
            if FileManager.default.fileExists(atPath: url.path) == false {
                return .failure(YAMLReadWriteError.fileDoesNotExist)
            }
            let text = try String(contentsOf: url)
            let decoder = YAMLDecoder()
            let object = try decoder.decode(HostClass.self, from: text)
            return .success(object)
        } catch {
            return .failure(error)
        }
    }

    func write(to url: URL) -> Result<Bool, Error> {
        do {
            let encoder = YAMLEncoder()
            let text = try encoder.encode(self)
            try text.write(to: url, atomically: true, encoding: .utf8)
        } catch {
            return .failure(error)
        }
        return .success(true)
    }
}
