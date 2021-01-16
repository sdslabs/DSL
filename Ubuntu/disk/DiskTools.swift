//
//  DiskTools.swift
//  Ubuntu
//
//  Created by Kanav Gupta on 16/01/21.
//

import Foundation

class DiskTools {
    static let qemuImg = Bundle.main.url(forResource: "qemu-img", withExtension: "")!.path
    static let mkfs = Bundle.main.url(forResource: "mkfs", withExtension: "")!.path

    static func removeExtension(path: String) -> String {
        var components = path.components(separatedBy: ".")
        if components.count > 1 {
            components.removeLast()
            return components.joined(separator: ".")
        }
        else {
            return path
        }
    }

    static func createQcowImage(path: URL, sizeInMegaBytes: Int) {
        let process = Process()
        process.launchPath = qemuImg
        process.arguments = [
            "create",
            "-f",
            "qcow2",
            path.path,
            "\(sizeInMegaBytes)M"
        ]
        process.launch()
        process.waitUntilExit()
    }

    static func createRawImage(path: URL, sizeInMegaBytes: Int) {
        let process = Process()
        process.launchPath = qemuImg
        process.arguments = [
            "create",
            "-f",
            "raw",
            path.path,
            "\(sizeInMegaBytes)M"
        ]
        process.launch()
        process.waitUntilExit()
    }

    static func raw2qcow(path: URL) throws {
        let process = Process()
        process.launchPath = qemuImg
        process.arguments = [
            "convert",
            "-f",
            "raw",
            "-O",
            "qcow2",
            path.path,
            "\(removeExtension(path: path.path)).qcow2"
        ]
        process.launch()
        process.waitUntilExit()
        try deleteFile(path: path)
    }

    static func deleteFile(path: URL) throws {
        try FileManager.default.removeItem(atPath: path.path)
    }

    static func mkfs(path: URL, label: String) {
        let process = Process()
        process.launchPath = mkfs
        process.arguments = [
            "-L",
            label,
            "-F",
            path.path
        ]
        process.launch()
        process.waitUntilExit()
    }
    
    static func createRawFilesystem(path: URL, sizeInMegaBytes: Int, label: String) {
        createRawImage(path: path, sizeInMegaBytes: sizeInMegaBytes)
        mkfs(path: path, label: label)
    }

    static func createQcowFileSystem(path: URL, sizeInMegaBytes: Int, label: String) throws {
        createRawFilesystem(path: path, sizeInMegaBytes: sizeInMegaBytes, label: label)
        try raw2qcow(path: path)
    }
    
    static func getDisksDirectory() throws -> URL {
        let appSupportDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let sdslabsPath = appSupportDirectory.appendingPathComponent("SDSLabs")
        let disksPath = sdslabsPath.appendingPathComponent("disks")
        if !FileManager.default.fileExists(atPath: disksPath.path) {
            try FileManager.default.createDirectory(at: disksPath, withIntermediateDirectories: false, attributes: nil)
        }
        return disksPath
    }
    
    static func createDisk(d: DiskImage) throws {
        let sizeInMegaBytes = d.storageUnit == .gb ? d.storage * 1024 : d.storage
        let disksPath = try getDisksDirectory()
        switch d.format {
        case .qcow2:
            try createQcowFileSystem(path: disksPath.appendingPathComponent("\(d.name).img"), sizeInMegaBytes: Int(sizeInMegaBytes), label: d.name)
        case .raw:
            createRawFilesystem(path: disksPath.appendingPathComponent("\(d.name).img"), sizeInMegaBytes: Int(sizeInMegaBytes), label: d.name)
        }
    }
}
