import Foundation
import UIKit

enum PhotoStoreError: Error {
    case directory
    case write
}

struct SavedPhotos: Sendable {
    let cleanPath: String
    let overlayPath: String
}

enum PhotoStore {
    static func directory() throws -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        guard let base else { throw PhotoStoreError.directory }
        let dir = base.appendingPathComponent("Photos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func save(id: UUID, clean: UIImage, overlay: UIImage, highQuality: Bool) throws -> SavedPhotos {
        let dir = try directory()
        let quality: CGFloat = highQuality ? 0.92 : 0.72
        let cleanURL = dir.appendingPathComponent("\(id.uuidString)-clean.jpg")
        let overlayURL = dir.appendingPathComponent("\(id.uuidString)-overlay.jpg")
        guard let cleanData = clean.jpegData(compressionQuality: quality),
              let overlayData = overlay.jpegData(compressionQuality: quality) else {
            throw PhotoStoreError.write
        }
        try cleanData.write(to: cleanURL, options: .atomic)
        try overlayData.write(to: overlayURL, options: .atomic)
        return SavedPhotos(cleanPath: cleanURL.path, overlayPath: overlayURL.path)
    }

    static func image(at path: String) -> UIImage? {
        UIImage(contentsOfFile: path)
    }

    static func delete(cleanPath: String, overlayPath: String) {
        try? FileManager.default.removeItem(atPath: cleanPath)
        try? FileManager.default.removeItem(atPath: overlayPath)
    }

    static func deleteAll() {
        guard let dir = try? directory() else { return }
        try? FileManager.default.removeItem(at: dir)
        _ = try? directory()
    }
}
