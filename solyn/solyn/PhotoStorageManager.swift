//
//  PhotoStorageManager.swift
//  solyn
//
//  Manages on-device photo storage for diary entries.
//  Photos are stored in Application Support/Photos/ (mirrors audio's Recordings/).
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

final class PhotoStorageManager {
    static let shared = PhotoStorageManager()

    private let photosDirectoryName = "Photos"

    private var photosDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent(photosDirectoryName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private init() {}

    // MARK: - Save

    #if canImport(UIKit)
    /// Save a photo and return its filename
    func savePhoto(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        let fileName = "\(UUID().uuidString).jpg"
        let fileURL = photosDirectory.appendingPathComponent(fileName)
        do {
            try data.write(to: fileURL)
            return fileName
        } catch {
            return nil
        }
    }
    #endif

    // MARK: - Load

    #if canImport(UIKit)
    func loadPhoto(fileName: String) -> UIImage? {
        let fileURL = photosDirectory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }
    #endif

    // MARK: - Delete

    func deletePhoto(fileName: String) {
        let fileURL = photosDirectory.appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - JSON Encoding Helpers

    static func parsePhotoFileNames(_ jsonString: String?) -> [String] {
        guard let jsonString, !jsonString.isEmpty,
              let data = jsonString.data(using: .utf8),
              let array = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return array
    }

    static func encodePhotoFileNames(_ fileNames: [String]) -> String {
        guard !fileNames.isEmpty,
              let data = try? JSONEncoder().encode(fileNames),
              let jsonString = String(data: data, encoding: .utf8) else {
            return ""
        }
        return jsonString
    }
}
