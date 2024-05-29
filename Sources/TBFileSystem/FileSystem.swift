import Foundation
import TBCommon
import os

/// Provides conveniences for accessing the file system.
@available(iOS 14.0, macOS 11.0, *)
public struct FileSystem {
    /// The underlying `FileManager`.
    public static let manager = FileManager.default
    private static let log = Logger(category: "filesystem")
    
    /// Provides the location of the `Documents` folder if successful; `nil` otherwise.
    public static var documentsURL: URL? {
        manager.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    /// Attempts to perform a shallow fetch of the `Documents` folder's contents.
    /// - Returns: If successful, an array of `URL`s that are the contents of the `Documents` folder.
    public static func documentsContents() throws -> [URL] {
        guard let folderURL = documentsURL else {
            throw FileSystemError.documentsFolderNotFound
        }

        return try manager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil, options: [])
    }
    
    /// Attempts to read the contents of the given `folderURL`
    /// - Parameter folderURL: The folder contents to be read.
    /// - Returns: An array of `URL`s pointing to the files contained by `folderURL`.
    public static func contentsOf(folderURL: URL) throws -> [URL] {
        try manager.contentsOfDirectory(at: folderURL, includingPropertiesForKeys: nil)
    }
    
    @available(macOS 13.0, *)
    /// Used for determining if a file of the given `filename` exists in the `Documents` folder.
    /// - Parameter filename: The name of the file to be checked.
    /// - Returns: `true` if the file exists in `Documents`; `false` otherwise.
    public static func fileExistsInDocuments(_ filename: String) -> Bool {
        guard let documentsURL = documentsURL else {
            return false
        }
        
        let fileURL = documentsURL.appending(path: filename, directoryHint: .notDirectory)
        return manager.fileExists(atPath: fileURL.path())
    }

    /// Logs to the console the path to an app's sandbox `Documents` folder.
    public static func logDocumentsURL() {
        if let docsUrl = documentsURL {
            log.debug("Documents folder path: \(docsUrl.path)")
        } else {
            log.warning("Documents folder not found")
        }
    }
}

/// Saves the given `text` to the a file called `filename` in the `Documents` folder.
/// - Parameters:
///   - text: The text to be saved.
///   - filename: The name of the file.
/// - Throws: On errors encountered when saving the text.
@available(iOS 14.0, macOS 11.0, *)
public func saveToDocuments(text: String, filename: String) throws {
    guard let docsURL = FileSystem.documentsURL else {
        throw FileSystemError.documentsFolderNotFound
    }
    let fileURL = docsURL.appendingPathComponent(filename)
    try text.write(to: fileURL, atomically: true, encoding: .utf8)
}

/// Attempts to load the contents of `filename` from the `Documents` folder.
/// - Parameter filename: The name of the file to be read.
/// - Throws: On errors encountered attempting to read the file contents.
/// - Returns: The contents of the file, as `Data`.
@available(iOS 14.0, macOS 11.0, *)
public func loadFromDocuments(from filename: String) throws -> Data {
    guard let docsURL = FileSystem.documentsURL else {
        throw FileSystemError.documentsFolderNotFound
    }
    let fileURL = docsURL.appendingPathComponent(filename)
    return try Data(contentsOf: fileURL)
}

/// Attempts to load the contents of the file at the given `fileURL`.
/// - Parameter fileURL: The URL of the file to be read.
/// - Throws: On errors encountered attempting to read the file contents.
/// - Returns: The contents of the file, as `Data`.
@available(iOS 10.0, OSX 10.12, *)
public func loadFromDocuments(fileURL: URL) throws -> Data {
    return try Data(contentsOf: fileURL)
}

/// Encodes the given `object` and saves it to the `Documents` folder using the given `filename`.
/// - Parameters:
///   - object: The object to be encoded and saved. It must implement `Codable`.
///   - filename: The name of the file to save to.
/// - Throws: On errors encountered attempting to encode or save the given object.
@available(iOS 14.0, macOS 11.0, *)
public func encodeAndSaveToDocuments<T: Codable>(_ object: T, filename: String) throws {
    let data = try encode(object)
    if let json = String(data: data, encoding: .utf8) {
        try saveToDocuments(text: json, filename: filename)
    } else {
        throw FileSystemError.unableToPersist(object: object, filename: filename)
    }
}

/// Encodes the given `thing` using a `JSONEncoder()` configured with all `outputFormatting` options.
/// - Parameter thing: The thing to be encoded.
/// - Returns: The encoded data if successful.
@available(iOS 13.0, macOS 10.15, *)
public func encode<T: Encodable>(_ thing: T) throws -> Data {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    return try encoder.encode(thing)
}

/// Retrieves the contents of `filename` and attempts to decode it into a `T` type.
/// - Parameters:
///   - filename: The contents to be fetched.
///   - decoder: The decoder to be used; a default one is provided.
/// - Throws: On errors encountered trying to load or decode the data.
/// - Returns: A newly minted instance of a `T` if successful.
@available(iOS 14.0, macOS 11.0, *)
public func loadAndDecodeFromDocuments<T: Codable>(filename: String,
                                                   decoder: JSONDecoder = JSONDecoder()) throws -> T {
    let data = try loadFromDocuments(from: filename)
    return try decoder.decode(T.self, from: data)
}

/// Indicates an error was encountered while working with the file system.
public enum FileSystemError: Error, LocalizedError {
    case failed(Error)
    case cachesFolderNotFound
    case documentsFolderNotFound
    case unableToPersist(object: Codable, filename: String)
    case unableToFetch(filename: String)
    case cloudContainerNotFound

    public var errorDescription: String? {
        switch self {
        case let .failed(error):
            return error.localizedDescription
        case .cachesFolderNotFound:
            return "Unable to find the caches folder."
        case .documentsFolderNotFound:
            return "Unable to find the Documents folder."
        case let .unableToFetch(filename):
            return "Unable to fetch \(filename) from Documents."
        case let .unableToPersist(object, filename):
            return "Unable to save \(object.self) to file \(filename)"
        case .cloudContainerNotFound:
            return "Cloud container not found"
        }
    }
}
