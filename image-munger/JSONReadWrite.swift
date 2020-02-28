//
//  JSONReadWrite.swift
//  TripWire
//
//  Created by Simeon Leifer on 1/20/20.
//  Copyright © 2020 droolingcat.com. All rights reserved.
//

import Foundation

protocol JSONReadWrite where Self: Codable {
    associatedtype HostClass: Codable

    static func read(contentsOf url: URL) -> Result<Self.HostClass, Error>
    func write(to url: URL, pretty: Bool) -> Result<Bool, Error>
}

enum JSONReadWriteError: Error {
    case fileDoesNotExist
}

extension JSONReadWrite {
    static func read(contentsOf url: URL) -> Result<Self.HostClass, Error> {
        do {
            if FileManager.default.fileExists(atPath: url.path) == false {
                return .failure(JSONReadWriteError.fileDoesNotExist)
            }
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let object = try decoder.decode(HostClass.self, from: data)
            return .success(object)
        } catch {
            return .failure(error)
        }
    }

    func write(to url: URL, pretty: Bool = false) -> Result<Bool, Error> {
        do {
            let encoder = JSONEncoder()
            if pretty == true {
                encoder.outputFormatting = .prettyPrinted
            }
            let data = try encoder.encode(self)
            try data.write(to: url, options: [.atomic])
        } catch {
            return .failure(error)
        }
        return .success(true)
    }
}
